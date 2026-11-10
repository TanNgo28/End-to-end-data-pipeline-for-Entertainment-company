SELECT device, CAST(event_count AS BIGINT) AS event_count,
       CAST(total_watch_seconds AS BIGINT) AS total_watch_seconds,
       round(average_watch_seconds, 2) AS average_watch_seconds
FROM oracle.entertainment_analytics.device_engagement
ORDER BY event_count DESC, device
