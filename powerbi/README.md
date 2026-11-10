# Entertainment Streaming Analytics

Open [Entertainment Streaming Analytics.pbip](Entertainment%20Streaming%20Analytics.pbip) in Power BI Desktop. The project uses an enhanced PBIR report and a TMDL model with relative project references. Use a Desktop build that supports all three formats. In releases that expose them as preview features, find Power BI Project, TMDL, and PBIR under **File → Options and settings → Options → Preview features**, then restart if required. In the May 2025 build the exact PBIR option is **Store reports using enhanced metadata format (PBIR)**.

## Open and refresh

1. Open the `.pbip` and select **Apply changes** if the report shows a pending-queries banner, then select **Home → Refresh** in **Demo** mode. This mode reads the published synthetic Gold aggregates embedded in the model. It works without a running Docker stack and carries no user data or credentials.
2. For current pipeline data, run `scripts/run_demo.sh` or start the serving phase. In Power BI Desktop, open **Transform data → Edit parameters**. Set `DataMode` to `Trino` and `TrinoBaseUrl` to `http://127.0.0.1:8080`, or use the `TRINO_PORT` from your local `.env`. Select **Anonymous** if Desktop asks for Web data source credentials for this local endpoint.
3. Select **Refresh**. The model uses Trino's statement HTTP API in Import mode. Trino queries `oracle.entertainment_analytics` using the SQL in [trino/sql](../trino/sql/). Oracle and storage credentials are configured inside Compose.
4. To refresh from files, run `scripts/export_dashboard.sh`, set `DataMode` to `CSV`, and point `CsvFolder` to the absolute path of the export folder accessible to Windows. Select **Refresh** again.

The report uses the loopback-only Compose endpoint. Local Power BI settings and cached model data belong in the ignored `.pbi` files. See the [acceptance record](../docs/evidence/README.md) for the scope of Desktop testing.


## Report pages

| Page | Decision it supports | Data |
|---|---|---|
| Streaming Overview | Compare plays, viewing time, device engagement and content completion | Existing streaming Gold tables |
| User Activity | Inspect hourly viewing activity and distinct users in the latest observed UTC hour | Silver streaming events aggregated into `hourly_user_activity` |
| Event Performance | Compare confirmed ticket sales, sell-through, check-ins and net ticket revenue by show | Synthetic venue bookings and payments in `event_performance` |
| Bookings & Payments | Track confirmed, cancelled and pending bookings, payment attempts, refunds and net revenue | Synthetic booking and payment projections in `booking_transactions` |
| Customer 360 | Explore viewing, membership, bookings, spend and check-ins per pseudonymous demo customer | Silver streaming joined by demo customer ID to synthetic venue and membership facts |
| Decision Pulse | Review demand trends, show attendance and payment declines together | Measures shared from the activity, venue and booking tables |

### Visual layout

Every page has a header band, four KPI cards and two rows of visuals. The report applies the `EntertainmentLakehouse.json` custom theme from `StaticResources/RegisteredResources`, which sets the categorical palette and table accent.

| Page | Visuals below the KPI cards |
|---|---|
| Streaming Overview | Daily plays line, daily watch-minutes area, Top 10 bar, device event-share donut, average watch seconds per device, content completion rate |
| User Activity | Hourly events line, active users per hour column, play share of events line, watch minutes area, hourly detail table |
| Event Performance | Category slicer, capacity / sold / check-in clustered bar, fill rate vs attendance scatter sized by revenue, revenue-by-category donut, revenue by show, extended show table with unsold seats, no-shows and average ticket revenue |
| Bookings & Payments | Status slicer, bookings by status, captured / declined / refunded payments, payment success gauge, cancellation and refund rate card, gross / refund / net VND by status, payment detail table |
| Customer 360 | Membership slicer, watch minutes by membership, watch-vs-spend scatter per customer, membership mix donut, average spend per customer, profile table |
| Decision Pulse | Hourly demand line, fill rate and attendance gauges, show attendance, declined payments, revenue treemap by category and show |

The model tables have no relationships, so each slicer filters only visuals built on its own table. The three slicers sit on pages whose visuals all use one table. Gauges use the hidden **Rate Scale Max** measure (100%) as the maximum. **Peak Hourly Users** is the maximum per-hour distinct-user count, not a distinct count across hours.

For an existing publication, rerun `scripts/refresh_lakehouse.sh`, then `scripts/sync_gold_to_oracle.sh` and `scripts/export_dashboard.sh` to materialize and serve the four new tables. Reopen the PBIP in Desktop and refresh. In the staged Compose workflow, run the ingestion and serving phases in the order documented in the root README.

The report uses Import. Flink's Kafka-to-Bronze path runs continuously during ingestion. Gold, Oracle and the PBIP are refreshed separately. **Users in Latest Hour** is scoped to the most recent observed UTC hour in the data. Venue, membership, booking and payment records in this extension are deterministic fixtures. They do not represent production integrations. Customer 360 includes only the pseudonymous demo IDs and carries no contact data.

## Measures and visual checks

| Visual | Definition and verification |
|---|---|
| Total Plays | Sums the Gold KPI play count. Only PLAY increments this metric. |
| Unique Viewers | Uses the global Gold distinct-viewer count. The measure avoids adding title-level unique counts. |
| Total Watch Time | Divides global Gold watch seconds by 60 and displays minutes. |
| Daily Streaming Trends | Plots plays by UTC date. The tooltip includes watch minutes. |
| Top 10 Most Popular Content | Uses the top-ten query on Gold content popularity, sorted by plays. |
| Device Engagement | Plots accepted event counts. Average watch time per event is in the tooltip. |
| Content Completion Rate | Uses COMPLETE ÷ (COMPLETE + STOP). Shows blank when no terminal events exist. This is a terminal-event metric for the synthetic stream. |

For the empty-stack demo, compare the cards with [streaming_kpis.csv](../docs/evidence/streaming_kpis.csv). Expected values are 79 plays, 30 unique viewers, and 298.65 minutes. Cross-check trends and completion counts with the [Trino outputs](../docs/evidence/), and confirm that every dataset in `reconcile.csv` has zero mismatches.

- [Microsoft Power BI project documentation](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview)
- [PBIR report format](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report)
- [TMDL model format](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset)
- [Trino statement protocol](https://trino.io/docs/current/develop/client-protocol.html)
