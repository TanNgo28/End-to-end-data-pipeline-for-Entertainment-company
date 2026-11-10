SELECT CAST(play_count AS BIGINT) AS play_count,
       CAST(unique_viewers AS BIGINT) AS unique_viewers,
       CAST(total_watch_seconds AS BIGINT) AS total_watch_seconds,
       round(CAST(total_watch_seconds AS DOUBLE) / 60, 2) AS total_watch_minutes
FROM oracle.entertainment_analytics.streaming_kpis
WHERE kpi_key = 'ALL'
