# Technical report

## Scope and verified architecture

The release packages the original video-streaming pipeline for a clean Docker Compose deployment. Its ingestion path is Kafka → Flink → Iceberg on SeaweedFS. Its serving path is Iceberg Gold → Oracle Database → Trino. Trino reads Iceberg for reconciliation and serves nine PBIP model tables and exports their data, full content popularity, and a reconciliation report. The [README](../README.md) contains the full architecture and demo commands.

Compose scopes the broker, catalog, and database volumes to the project. The Flink image builds its classpath from five SHA-256-verified Maven artifacts. The Python image builds from pinned direct dependencies and includes the producer, Iceberg materialization, and Oracle loader. Flink jobs and Python tools share the checkout's local recovery and publication directory through a bind mount. The Kafka, SeaweedFS, and Oracle volume data are outside the Git repository.

## Processing, recovery, and consistency

| Boundary | Mechanism |
|---|---|
| Producer → Kafka | `event_id` is the message key. The demo producer uses broker idempotence within a session and verifies payloads by partition and offset with a separate consumer. A stable run ID produces deterministic demo records across invocations. |
| Kafka → Iceberg Bronze | Flink parses the JSON contract and drops rows with missing required fields or invalid timestamps. An append-only processing-time deduplication operator keeps the first event for each ID. Kafka offsets and deduplication state are captured in checkpoints. The Iceberg sink publishes Parquet files in table snapshots. |
| Bronze → Silver | A bounded PyIceberg scan pins the input snapshot. The transform normalizes event type and device, rejects unsupported event types, and coerces null and negative durations to zero. Kafka lineage remains on the clean rows. |
| Silver → Gold | A single local process refreshes content popularity, device engagement, global KPIs, daily streaming, and content completion. The publication manifest names the nine committed snapshots. Identical rows retain their existing snapshots. |
| Gold → Oracle | The loader verifies the published snapshot IDs, applies `MERGE` by the primary key, reconciles stale keys, and checks each table against Iceberg before committing. One DML transaction covers all nine serving tables. |
| Oracle → Trino | A read-only Trino instance queries Oracle through JDBC. An independent SQL aggregation from Silver is compared with both Iceberg Gold and Oracle. CSV export succeeds only when all nine mismatch counts equal zero. |

Normal shutdown creates a Flink savepoint before stopping the cluster. Restart finds the savepoint or a retained checkpoint and restores the previous topology. If the repository has a job marker but recovery metadata is missing, startup stops for operator investigation. Recovery and deduplication are scoped to the retained state of this deployment.

The Gold manifest is written after all nine table writes pass read-back. Oracle load and snapshot publication are serialized using a local lock. Direct Iceberg readers may observe individual table commits during a refresh. If a refresh ends partway through, Oracle retains the previous transaction and the loader checks the manifest before loading a new publication.

## Data model and metrics

| Dataset | Key | Metrics |
|---|---|---|
| `content_popularity` | `content_id` | Play count, distinct viewers with at least one play for the title, total watch seconds, total watch minutes |
| `device_engagement` | `device` | Event count, total watch seconds, average watch seconds per accepted event |
| `streaming_kpis` | `kpi_key = 'ALL'` | Play count, distinct viewers across all titles, total watch seconds |
| `daily_streaming_trends` | UTC `event_date` | Daily play count and watch seconds |
| `content_completion` | `content_id` | COMPLETE and STOP event counts |

Only a `PLAY` increments play count or qualifies a viewer. All supported event types can contribute incremental watch duration. A viewer can appear in multiple titles, so the global distinct count is calculated from Silver events. The completion rate is COMPLETE ÷ (COMPLETE + STOP), which measures terminal events in this synthetic event model.

## Isolation and release hygiene

The clean test used a separate clone, Compose project, ports, named volumes, and generated credentials. The existing deployment's service containers were paused while the test ran on the same memory-constrained WSL host. The acceptance record documents their restoration and the data checks.

Local credentials are generated into a mode-0600 `.env`. The file, runtime state, downloaded artifacts, caches, backups, and logs are excluded from Git. Docker's build context is restricted to the source and manifests required for the two images. Compose exposes only Flink and Trino to host loopback. Treat Docker daemon access as privileged on the local host.

The acceptance evidence tracks only a small set of CSVs produced by the synthetic clean test and the corresponding test summary. The original stack's event data and operating files were kept outside the publication repository.

## Operating limits and extensions

The PoC runs single-node Kafka and SeaweedFS with Flink parallelism 1. Checkpoints and savepoints live on local disk. Silver and Gold refresh read up to 100,000 rows and use a bounded full-snapshot model. This design has no cross-host recovery or BI refresh latency guarantee. Production design would use replicated Kafka, durable distributed Flink state, incremental transforms, and alerts for consumer lag, failed commits, stale snapshots, and serving freshness.

| Proposed domain | Ingestion design | Example serving output |
|---|---|---|
| Booking | Publish `booking-events` through a transactional outbox keyed by `booking_id`. Apply only newer entity versions when updating booking state. | Booking funnel, cancellations, inventory per performance |
| Payments | Publish `payment-events` keyed by `payment_id`, with event type, amount in minor units, currency, and entity version. | Charges, refunds, and net revenue per currency |
| Live events | Publish catalog changes keyed by `show_id` and attendance events keyed by `ticket_id`. | Sell-through, check-ins, and no-shows |
| Membership | Publish `membership-events` keyed by `subscription_id`. | Renewals, cancellations, and active membership |
| Customer 360 | Resolve source-specific customer identifiers into a restricted `customer_key` and combine accepted events and entity states. | Last activity, viewing, purchase and attendance history, current subscription |

Add explicit `schema_version`, event time, ingest time, and idempotency keys for additional domains. For late or invalid events, define event-time policies and a quarantine topic. The PBIP extension models synthetic venue bookings, payments and membership. It aggregates these fixtures and actual demo streaming activity into four additional Gold tables. Production ingestion for these domains remains an extension.

## Acceptance evidence

See [the clean-deployment record](evidence/README.md) for actual results, command traces summarized without credentials, and the Power BI Desktop verification status.

## Business intelligence extension

The extended Gold publication adds hourly streaming activity, show-level performance, booking status/payment totals and customer-level profiles. The venue generator creates one synthetic booking per attempted ticket. Captured payments include refunded captures, and net revenue subtracts refunds from gross captures. Ticket fill is confirmed tickets divided by capacity. Attendance is check-ins divided by confirmed tickets. The payment decline rate uses declined attempts divided by captured plus declined attempts.

Customer 360 joins only fixed pseudonymous demo IDs to streaming activity, membership and venue facts. It distinguishes customers with both viewing events and confirmed bookings. The four extension tables are included in the same Gold snapshot manifest and Oracle transaction as the streaming tables. The Trino reconciliation compares each extension table with its Oracle mirror in both directions. The bundled extension CSVs are fixture aggregates for Demo mode.
