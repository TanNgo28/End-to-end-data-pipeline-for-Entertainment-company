SELECT customer_id, membership, last_stream_utc, CAST(streaming_events AS BIGINT) AS streaming_events, CAST(plays AS BIGINT) AS plays, CAST(watch_seconds AS BIGINT) AS watch_seconds, CAST(bookings AS BIGINT) AS bookings, CAST(confirmed AS BIGINT) AS confirmed, CAST(net_spend_vnd AS BIGINT) AS net_spend_vnd, CAST(check_ins AS BIGINT) AS check_ins
FROM oracle.entertainment_analytics.customer_360
ORDER BY customer_id
