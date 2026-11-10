WITH source_rows AS (
  SELECT * FROM iceberg.silver.streaming_events_clean
),
expected_content AS (
  SELECT content_id, count_if(event_type = 'PLAY') AS plays,
         count(DISTINCT user_id) FILTER (WHERE event_type = 'PLAY') AS viewers,
         sum(watch_duration_seconds) AS seconds
  FROM source_rows GROUP BY content_id
),
expected_devices AS (
  SELECT device, count(*) AS events, sum(watch_duration_seconds) AS seconds
  FROM source_rows GROUP BY device
),
expected_kpis AS (
  SELECT 'ALL' AS kpi_key, count_if(event_type = 'PLAY') AS plays,
         count(DISTINCT user_id) FILTER (WHERE event_type = 'PLAY') AS viewers,
         coalesce(sum(watch_duration_seconds), 0) AS seconds
  FROM source_rows
),
content_diff AS (
  SELECT coalesce(e.content_id, g.content_id, o.content_id) AS id
  FROM expected_content e
  FULL JOIN iceberg.gold.content_popularity g ON e.content_id = g.content_id
  FULL JOIN oracle.entertainment_analytics.content_popularity o
    ON coalesce(e.content_id, g.content_id) = o.content_id
  WHERE e.plays IS DISTINCT FROM g.play_count OR g.play_count IS DISTINCT FROM o.play_count
     OR e.viewers IS DISTINCT FROM g.unique_viewers OR g.unique_viewers IS DISTINCT FROM o.unique_viewers
     OR e.seconds IS DISTINCT FROM g.total_watch_seconds
     OR g.total_watch_seconds IS DISTINCT FROM o.total_watch_seconds
     OR CAST(e.seconds AS DOUBLE) / 60 IS DISTINCT FROM g.total_watch_minutes
     OR g.total_watch_minutes IS DISTINCT FROM o.total_watch_minutes
),
device_diff AS (
  SELECT coalesce(e.device, g.device, o.device) AS id
  FROM expected_devices e
  FULL JOIN iceberg.gold.device_engagement g ON e.device = g.device
  FULL JOIN oracle.entertainment_analytics.device_engagement o
    ON coalesce(e.device, g.device) = o.device
  WHERE e.events IS DISTINCT FROM g.event_count OR g.event_count IS DISTINCT FROM o.event_count
     OR e.seconds IS DISTINCT FROM g.total_watch_seconds
     OR g.total_watch_seconds IS DISTINCT FROM o.total_watch_seconds
     OR CAST(e.seconds AS DOUBLE) / e.events IS DISTINCT FROM g.average_watch_seconds
     OR g.average_watch_seconds IS DISTINCT FROM o.average_watch_seconds
),
kpi_diff AS (
  SELECT coalesce(e.kpi_key, g.kpi_key, o.kpi_key) AS id
  FROM expected_kpis e
  FULL JOIN iceberg.gold.streaming_kpis g ON e.kpi_key = g.kpi_key
  FULL JOIN oracle.entertainment_analytics.streaming_kpis o
    ON coalesce(e.kpi_key, g.kpi_key) = o.kpi_key
  WHERE e.plays IS DISTINCT FROM g.play_count OR g.play_count IS DISTINCT FROM o.play_count
     OR e.viewers IS DISTINCT FROM g.unique_viewers OR g.unique_viewers IS DISTINCT FROM o.unique_viewers
     OR e.seconds IS DISTINCT FROM g.total_watch_seconds
     OR g.total_watch_seconds IS DISTINCT FROM o.total_watch_seconds
)
SELECT 'content_popularity' AS dataset, count(*) AS mismatches FROM content_diff
UNION ALL SELECT 'device_engagement', count(*) FROM device_diff
UNION ALL SELECT 'streaming_kpis', count(*) FROM kpi_diff
ORDER BY dataset
