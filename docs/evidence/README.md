# Clean deployment and Power BI acceptance

The test ran on 2026-11-10 in Ubuntu WSL 2 on x86-64 with Docker Engine 29.9.3, Docker Compose v5.7.0, 3.7 GiB RAM, and 1 GiB swap. The fresh clone of runtime commit `0f28ab9` used project `entertainment-pbip-qa`, loopback ports 18081 and 18080, and new Kafka, SeaweedFS, and Oracle volumes. The checkout started without an environment file, virtual environment, runtime state, or JARs. A separate cold build downloaded all five Maven JARs and validated their SHA-256 checksums. The final clone reused those verified build layers.

| Boundary | Status | Observed result |
|---|---|---|
| Build and initialization | PASS | Built both custom images, initialized a single-partition Kafka topic and the SeaweedFS table bucket, and created the Iceberg namespaces and Bronze table. |
| Kafka | PASS | Acknowledged 240 events at partition 0, offsets 0–239. A separate consumer verified all 240 payloads. |
| Flink and Bronze | PASS | Flink committed event `compose-demo-0240` in Iceberg v2 Parquet snapshot `3643249414844144396`. Read-back found [240 rows and 240 distinct IDs](bronze-count.csv). The ingestion job stopped with a savepoint. |
| Silver and Gold | PASS | Silver snapshot `2283734619013213018` contained 240 clean rows. Gold had 12 content rows, 4 device rows, 1 KPI row, 7 UTC dates, and 12 completion rows. A second materialization retained all five Gold snapshot IDs. |
| Oracle | PASS | Free Lite 23.26.3.0.0 initialized from an empty volume. The loader verified all rows of all five tables and committed the publication. |
| Trino | PASS | Trino queried Oracle and Iceberg. [Reconciliation](reconcile.csv) returned zero mismatches across five Gold datasets. A separate statement-API check queried all five PBIP datasets through Trino's HTTP endpoint. |
| Power BI Desktop, Demo | PASS | Opened the PBIP on Desktop 2.143.878.0 (May 2025) with the PBIR preview feature enabled. Applied the model queries and observed all four KPI cards and the daily, top-ten, device, and completion charts. |
| Power BI Desktop, Trino and CSV import | NOT RUN | The Trino statement API and CSV outputs were tested independently. An in-app refresh was performed in Demo mode. |

The verified [Power BI Desktop screenshot](powerbi-desktop-demo.jpeg) shows **79 plays, 30 unique viewers, 298.65 watch minutes, and 75.0% completion**. Completion was 45 COMPLETE events out of 60 terminal events. The five inline Demo tables match the Trino CSV exports. All 16 project and report JSON files passed Microsoft schema validation. Desktop's installed Analysis Services library parsed the TMDL model and found five tables, eleven measures, and four shared Power Query expressions.

Gold snapshot IDs were `1674605905951414308` for content, `1575697708381230248` for devices, `901980472167283629` for KPIs, `5001156992794865623` for daily trends, and `6839903034459215519` for completion.

## Reproduce the smoke test

```bash
scripts/init_env.sh entertainment-release-local 18081 18080
scripts/run_demo.sh
cat .runtime/exports/streaming_kpis.csv
cat .runtime/exports/reconcile.csv
```

On a cold start, the Oracle health check can succeed before its entrypoint finishes setting the administrative password. The serving script waits for the container to report healthy and for the current start's readiness marker. That sequence passed on a new Oracle volume.

To inspect Power BI, open the [PBIP project](../../powerbi/Entertainment%20Streaming%20Analytics.pbip), apply pending changes if prompted, and use the [refresh guide](../../powerbi/README.md).

## Existing environment preservation

The original stack was temporarily paused to fit the isolated test on the same host. Its four running containers were restarted with the same IDs. All three original volume descriptors matched before and after. A read-back confirmed the original Bronze snapshot `6715215029120248104` still had 243 distinct events and the original Oracle KPI remained 81 plays, 33 unique viewers, and 16,068 seconds. The QA stack was stopped.

## Publication review

The original project directory did not have Git history. The publication repository began with an explicit copy of selected source files. The handoff checks scan all reachable history using Gitleaks v8.30.1, compare the known local credential values against all Git objects without printing them, and verify that no historical path contains runtime data, cached Power BI models, or JARs.

```bash
git status --short
git log --oneline --all
git fsck --strict
```
