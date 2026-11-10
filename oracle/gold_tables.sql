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
