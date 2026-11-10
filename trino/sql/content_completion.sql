SELECT content_id, CAST(completed_count AS BIGINT) AS completed_count,
       CAST(stopped_count AS BIGINT) AS stopped_count
FROM oracle.entertainment_analytics.content_completion
ORDER BY content_id
