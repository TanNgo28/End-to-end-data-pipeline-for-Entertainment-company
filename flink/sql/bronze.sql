CREATE DATABASE IF NOT EXISTS bronze;
CREATE DATABASE IF NOT EXISTS silver;
CREATE DATABASE IF NOT EXISTS gold;

CREATE TABLE IF NOT EXISTS bronze.streaming_events (
  event_id STRING NOT NULL,
  user_id STRING NOT NULL,
  content_id STRING NOT NULL,
  event_type STRING NOT NULL,
  watch_duration_seconds INT,
  device STRING NOT NULL,
  event_timestamp TIMESTAMP_LTZ(3) NOT NULL,
  kafka_partition INT,
  kafka_offset BIGINT
) WITH (
  'format-version' = '2',
  'write.format.default' = 'parquet'
);
