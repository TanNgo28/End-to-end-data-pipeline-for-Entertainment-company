SELECT hour_utc, CAST(event_count AS BIGINT) AS event_count, CAST(play_count AS BIGINT) AS play_count, CAST(active_users AS BIGINT) AS active_users, CAST(watch_seconds AS BIGINT) AS watch_seconds
FROM oracle.entertainment_analytics.hourly_user_activity
ORDER BY hour_utc
