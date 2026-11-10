SELECT content_id, CAST(play_count AS BIGINT) AS play_count,
       CAST(unique_viewers AS BIGINT) AS unique_viewers,
       CAST(total_watch_seconds AS BIGINT) AS total_watch_seconds,
       round(total_watch_minutes, 2) AS total_watch_minutes
FROM oracle.entertainment_analytics.content_popularity
ORDER BY play_count DESC, content_id
