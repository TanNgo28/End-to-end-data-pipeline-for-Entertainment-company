CREATE TEMPORARY TABLE streaming_events_source (
  event_id STRING,
  user_id STRING,
  content_id STRING,
  event_type STRING,
  watch_duration_seconds INT,
  device STRING,
  event_timestamp TIMESTAMP_LTZ(3),
  kafka_partition INT METADATA FROM 'partition' VIRTUAL,
  kafka_offset BIGINT METADATA FROM 'offset' VIRTUAL,
  ingest_time AS PROCTIME()
) WITH (
  'connector' = 'kafka',
  'topic' = 'streaming-events',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'entertainment-bronze-v1',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'json',
  'json.timestamp-format.standard' = 'ISO-8601',
  'json.ignore-parse-errors' = 'true'
);
