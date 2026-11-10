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
expected_daily AS (
  SELECT CAST(CAST(event_timestamp AT TIME ZONE 'UTC' AS DATE) AS VARCHAR) AS event_date,
         count_if(event_type = 'PLAY') AS plays, sum(watch_duration_seconds) AS seconds
  FROM source_rows GROUP BY 1
),
expected_completion AS (
  SELECT content_id, count_if(event_type = 'COMPLETE') AS completed,
         count_if(event_type = 'STOP') AS stopped
  FROM source_rows GROUP BY content_id
),
daily_diff AS (
  SELECT coalesce(e.event_date, g.event_date, o.event_date) AS id
  FROM expected_daily e
  FULL JOIN iceberg.gold.daily_streaming_trends g ON e.event_date = g.event_date
  FULL JOIN oracle.entertainment_analytics.daily_streaming_trends o
    ON coalesce(e.event_date, g.event_date) = o.event_date
  WHERE e.plays IS DISTINCT FROM g.play_count OR g.play_count IS DISTINCT FROM o.play_count
     OR e.seconds IS DISTINCT FROM g.total_watch_seconds
     OR g.total_watch_seconds IS DISTINCT FROM o.total_watch_seconds
),
completion_diff AS (
  SELECT coalesce(e.content_id, g.content_id, o.content_id) AS id
  FROM expected_completion e
  FULL JOIN iceberg.gold.content_completion g ON e.content_id = g.content_id
  FULL JOIN oracle.entertainment_analytics.content_completion o
    ON coalesce(e.content_id, g.content_id) = o.content_id
  WHERE e.completed IS DISTINCT FROM g.completed_count OR g.completed_count IS DISTINCT FROM o.completed_count
     OR e.stopped IS DISTINCT FROM g.stopped_count OR g.stopped_count IS DISTINCT FROM o.stopped_count
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
UNION ALL SELECT 'daily_streaming_trends', count(*) FROM daily_diff
UNION ALL SELECT 'content_completion', count(*) FROM completion_diff
ORDER BY dataset
