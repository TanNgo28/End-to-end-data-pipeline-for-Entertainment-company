SELECT content_id, CAST(play_count AS BIGINT) AS play_count
FROM oracle.entertainment_analytics.content_popularity
WHERE play_count > 0
ORDER BY play_count DESC, content_id
LIMIT 10
