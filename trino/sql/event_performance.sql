SELECT show_id, show_name, category, CAST(capacity AS BIGINT) AS capacity, CAST(sold AS BIGINT) AS sold, CAST(checked_in AS BIGINT) AS checked_in, CAST(net_revenue_vnd AS BIGINT) AS net_revenue_vnd
FROM oracle.entertainment_analytics.event_performance
ORDER BY show_id
