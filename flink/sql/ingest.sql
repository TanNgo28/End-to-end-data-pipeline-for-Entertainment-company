SET 'execution.runtime-mode' = 'streaming';
SET 'pipeline.name' = 'entertainment-kafka-bronze';
SET 'parallelism.default' = '1';
SET 'execution.checkpointing.interval' = '10 s';
SET 'execution.checkpointing.min-pause' = '5 s';
SET 'execution.checkpointing.timeout' = '2 min';
SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.externalized-checkpoint-retention' = 'RETAIN_ON_CANCELLATION';
SET 'execution.checkpointing.dir' = 'file:///opt/flink/pipeline-state/checkpoints';

INSERT INTO bronze.streaming_events
SELECT event_id, user_id, content_id, event_type, watch_duration_seconds,
       device, event_timestamp, kafka_partition, kafka_offset
FROM (
  SELECT TRIM(event_id) AS event_id, user_id, content_id, event_type,
         watch_duration_seconds, device, event_timestamp, kafka_partition, kafka_offset,
         ROW_NUMBER() OVER (PARTITION BY TRIM(event_id) ORDER BY ingest_time ASC) AS event_rank
  FROM streaming_events_source
  WHERE event_id IS NOT NULL AND TRIM(event_id) <> ''
    AND user_id IS NOT NULL AND TRIM(user_id) <> ''
    AND content_id IS NOT NULL AND TRIM(content_id) <> ''
    AND event_type IS NOT NULL AND TRIM(event_type) <> ''
    AND device IS NOT NULL AND TRIM(device) <> ''
    AND event_timestamp IS NOT NULL
)
WHERE event_rank = 1;
