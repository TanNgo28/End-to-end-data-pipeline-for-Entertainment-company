SELECT event_date, CAST(play_count AS BIGINT) AS play_count,
       CAST(total_watch_seconds AS BIGINT) AS total_watch_seconds
FROM oracle.entertainment_analytics.daily_streaming_trends
ORDER BY event_date
