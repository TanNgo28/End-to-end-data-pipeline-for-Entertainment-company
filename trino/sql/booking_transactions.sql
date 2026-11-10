SELECT booking_status, CAST(booking_count AS BIGINT) AS booking_count, CAST(payments_captured AS BIGINT) AS payments_captured, CAST(payments_declined AS BIGINT) AS payments_declined, CAST(refunds AS BIGINT) AS refunds, CAST(gross_vnd AS BIGINT) AS gross_vnd, CAST(refund_vnd AS BIGINT) AS refund_vnd
FROM oracle.entertainment_analytics.booking_transactions
ORDER BY booking_status
