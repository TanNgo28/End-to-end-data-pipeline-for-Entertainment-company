# Entertainment Streaming Analytics

Open [Entertainment Streaming Analytics.pbip](Entertainment%20Streaming%20Analytics.pbip) in Power BI Desktop. The project uses an enhanced PBIR report and a TMDL model with relative project references. Use a Desktop build that supports all three formats. In releases that expose them as preview features, find Power BI Project, TMDL, and PBIR under **File → Options and settings → Options → Preview features**, then restart if required. In the May 2025 build the exact PBIR option is **Store reports using enhanced metadata format (PBIR)**.

## Open and refresh

1. Open the `.pbip` and select **Apply changes** if the report shows a pending-queries banner, then select **Home → Refresh** in **Demo** mode. This mode reads the published synthetic Gold aggregates embedded in the model. It works without a running Docker stack and carries no user data or credentials.
2. For current pipeline data, run `scripts/run_demo.sh` or start the serving phase. In Power BI Desktop, open **Transform data → Edit parameters**. Set `DataMode` to `Trino` and `TrinoBaseUrl` to `http://127.0.0.1:8080`, or use the `TRINO_PORT` from your local `.env`. Select **Anonymous** if Desktop asks for Web data source credentials for this local endpoint.
3. Select **Refresh**. The model uses Trino's statement HTTP API in Import mode. Trino queries `oracle.entertainment_analytics` using the SQL in [trino/sql](../trino/sql/). Oracle and storage credentials are configured inside Compose.
4. To refresh from files, run `scripts/export_dashboard.sh`, set `DataMode` to `CSV`, and point `CsvFolder` to the absolute path of the export folder accessible to Windows. Select **Refresh** again.

The report uses the loopback-only Compose endpoint. Local Power BI settings and cached model data belong in the ignored `.pbi` files. See the [acceptance record](../docs/evidence/README.md) for the scope of Desktop testing.

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
