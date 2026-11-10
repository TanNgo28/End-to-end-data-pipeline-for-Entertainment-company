CREATE TABLE IF NOT EXISTS content_popularity (
  content_id VARCHAR2(400 BYTE) PRIMARY KEY,
  play_count NUMBER(19,0) NOT NULL,
  unique_viewers NUMBER(19,0) NOT NULL,
  total_watch_seconds NUMBER(19,0) NOT NULL,
  total_watch_minutes BINARY_DOUBLE NOT NULL
);

CREATE TABLE IF NOT EXISTS device_engagement (
  device VARCHAR2(400 BYTE) PRIMARY KEY,
  event_count NUMBER(19,0) NOT NULL,
  total_watch_seconds NUMBER(19,0) NOT NULL,
  average_watch_seconds BINARY_DOUBLE NOT NULL
);

CREATE TABLE IF NOT EXISTS streaming_kpis (
  kpi_key VARCHAR2(20 BYTE) PRIMARY KEY,
  play_count NUMBER(19,0) NOT NULL,
  unique_viewers NUMBER(19,0) NOT NULL,
  total_watch_seconds NUMBER(19,0) NOT NULL
);

CREATE TABLE IF NOT EXISTS daily_streaming_trends (
  event_date VARCHAR2(10 BYTE) PRIMARY KEY,
  play_count NUMBER(19,0) NOT NULL,
  total_watch_seconds NUMBER(19,0) NOT NULL
);

CREATE TABLE IF NOT EXISTS content_completion (
  content_id VARCHAR2(400 BYTE) PRIMARY KEY,
  completed_count NUMBER(19,0) NOT NULL,
  stopped_count NUMBER(19,0) NOT NULL
);

CREATE TABLE IF NOT EXISTS hourly_user_activity (
  hour_utc VARCHAR2(16 BYTE) PRIMARY KEY,
  event_count NUMBER(19,0) NOT NULL,
  play_count NUMBER(19,0) NOT NULL,
  active_users NUMBER(19,0) NOT NULL,
  watch_seconds NUMBER(19,0) NOT NULL
);

CREATE TABLE IF NOT EXISTS event_performance (
  show_id VARCHAR2(12 BYTE) PRIMARY KEY,
  show_name VARCHAR2(100 BYTE) NOT NULL,
  category VARCHAR2(40 BYTE) NOT NULL,
  capacity NUMBER(19,0) NOT NULL,
  sold NUMBER(19,0) NOT NULL,
  checked_in NUMBER(19,0) NOT NULL,
  net_revenue_vnd NUMBER(19,0) NOT NULL
);

CREATE TABLE IF NOT EXISTS booking_transactions (
  booking_status VARCHAR2(40 BYTE) PRIMARY KEY,
  booking_count NUMBER(19,0) NOT NULL,
  payments_captured NUMBER(19,0) NOT NULL,
  payments_declined NUMBER(19,0) NOT NULL,
  refunds NUMBER(19,0) NOT NULL,
  gross_vnd NUMBER(19,0) NOT NULL,
  refund_vnd NUMBER(19,0) NOT NULL
);

CREATE TABLE IF NOT EXISTS customer_360 (
  customer_id VARCHAR2(80 BYTE) PRIMARY KEY,
  membership VARCHAR2(30 BYTE) NOT NULL,
  last_stream_utc VARCHAR2(19 BYTE),
  streaming_events NUMBER(19,0) NOT NULL,
  plays NUMBER(19,0) NOT NULL,
  watch_seconds NUMBER(19,0) NOT NULL,
  bookings NUMBER(19,0) NOT NULL,
  confirmed NUMBER(19,0) NOT NULL,
  net_spend_vnd NUMBER(19,0) NOT NULL,
  check_ins NUMBER(19,0) NOT NULL
);
