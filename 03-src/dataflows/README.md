# Dataflows Gen2

Fabric Dataflows Gen2 for IPC and IPI, and for the dimensions. One `.pq` file
(exported M) per dataflow.

| File | Layer | Loads |
|---|---|---|
| `spi_df_silver_ipc.pq` | Silver | `spi_bronze_ipc_raw` → `spi_silver_ipc_cleaned` (Replace) |
| `spi_df_silver_ipi.pq` | Silver | `spi_bronze_ipi_raw` → `spi_silver_ipi_cleaned` (Replace) |
| `spi_df_gold_ipc.pq` | Gold | `spi_silver_ipc_cleaned` → `spi_fact_indicators` (Append) |
| `spi_df_gold_ipi.pq` | Gold | `spi_silver_ipi_cleaned` → `spi_fact_indicators` (Append) |
| `spi_df_gold_dimensions.pq` | Gold | `spi_dim_region`, `spi_dim_calendar`, `spi_dim_indicator` (Replace) |

The Gold IPC and IPI dataflows append to the shared fact table. The rows of
their source are deleted first (`WHERE source_key = n`, ADR-010). Until
Sprint 7, that DELETE is run manually before each Gold refresh.

`spi_df_gold_dimensions` owns the three dimensions it loads (ADR-010).
