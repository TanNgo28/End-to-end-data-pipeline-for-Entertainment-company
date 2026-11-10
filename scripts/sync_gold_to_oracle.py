"""Synchronize a published set of Iceberg Gold snapshots to local Oracle."""
import argparse
import json
import os
import re
import time

import oracledb

from lakehouse import GOLD, GOLD_SCHEMAS, PUBLISHED, ROOT, catalog, publication_lock, read_rows

USER = "ENTERTAINMENT_ANALYTICS"
DSN = os.environ["ORACLE_DSN"]


def password():
    return os.environ["ORACLE_ANALYTICS_PASSWORD"]


def bootstrap():
    secret = password()
    if not re.fullmatch(r"[A-Za-z0-9_#]{12,64}", secret):
        raise RuntimeError("Use a 12–64 character Oracle analytics password from [A-Za-z0-9_#]")
    with publication_lock(), oracledb.connect(user="SYSTEM", password=os.environ["ORACLE_PWD"], dsn=DSN) as conn:
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1 FROM dba_tablespaces WHERE tablespace_name = 'ENTERTAINMENT_DATA'")
            if not cursor.fetchone():
                cursor.execute(
                    "SELECT file_name FROM dba_data_files WHERE tablespace_name = 'SYSTEM' AND rownum = 1"
                )
                directory = cursor.fetchone()[0].rsplit("/", 1)[0]
                datafile = (directory + "/entertainment_data01.dbf").replace("'", "''")
                cursor.execute(
                    f"CREATE TABLESPACE entertainment_data DATAFILE '{datafile}' "
                    "SIZE 32M AUTOEXTEND ON NEXT 16M MAXSIZE 128M"
                )
            cursor.execute("SELECT 1 FROM dba_users WHERE username = :name", name=USER)
            if not cursor.fetchone():
                cursor.execute(
                    f'CREATE USER {USER} IDENTIFIED BY "{secret}" '
                    "DEFAULT TABLESPACE entertainment_data QUOTA 100M ON entertainment_data"
                )
            cursor.execute(f"GRANT CREATE SESSION, CREATE TABLE TO {USER}")


def connect(wait=0):
    deadline = time.monotonic() + wait
    while True:
        try:
            return oracledb.connect(user=USER, password=password(), dsn=DSN)
        except oracledb.DatabaseError as error:
            if time.monotonic() >= deadline:
                raise
            details = error.args[0]
            if details.code == 1017:
                raise
            time.sleep(3)


def merge(cursor, name, columns, rows):
    key, *values = columns
    source = ", ".join(f":{column} {column}" for column in columns)
    updates = ", ".join(f"t.{column} = s.{column}" for column in values)
    fields = ", ".join(columns)
    inserts = ", ".join(f"s.{column}" for column in columns)
    if rows:
        cursor.executemany(
            f"MERGE INTO {name} t USING (SELECT {source} FROM dual) s ON (t.{key} = s.{key}) "
            f"WHEN MATCHED THEN UPDATE SET {updates} "
            f"WHEN NOT MATCHED THEN INSERT ({fields}) VALUES ({inserts})",
            rows,
        )
    cursor.execute(f"SELECT {key} FROM {name}")
    expected = {row[key] for row in rows}
    stale = [(value,) for (value,) in cursor if value not in expected]
    if stale:
        cursor.executemany(f"DELETE FROM {name} WHERE {key} = :1", stale)
    cursor.execute(f"SELECT {fields} FROM {name}")
    actual = {row[0]: row for row in cursor}
    planned = {row[key]: tuple(row[column] for column in columns) for row in rows}
    if actual != planned:
        raise RuntimeError(f"Oracle read-back differs from Iceberg: {name}")


def sync():
    with publication_lock():
        lake = catalog()
        snapshots = json.loads(PUBLISHED.read_text())
        with connect() as connection, connection.cursor() as cursor:
            for ddl in (ROOT / "oracle/gold_tables.sql").read_text().split(";"):
                if ddl.strip():
                    cursor.execute(ddl)
            for identifier, schema in zip(GOLD, GOLD_SCHEMAS, strict=True):
                table = lake.load_table(identifier)
                snapshot = snapshots[identifier]
                if table.current_snapshot().snapshot_id != snapshot:
                    raise RuntimeError("Incomplete Gold publication. Rerun refresh_lakehouse.sh.")
                rows = read_rows(table, snapshot)
                name = identifier.split(".")[-1]
                merge(cursor, name, schema.names, rows)
                print(f"{name.upper()}: verified {len(rows)} rows from snapshot {snapshot}")
            connection.commit()
            cursor.execute("SELECT play_count, unique_viewers, total_watch_seconds FROM streaming_kpis")
            print(f"Oracle {connection.version} committed KPI: {cursor.fetchone()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bootstrap", action="store_true")
    args = parser.parse_args()
    if args.bootstrap:
        bootstrap()
        with connect(wait=30) as connection:
            print(f"Oracle {connection.version}: analytics account connected")
    else:
        sync()
