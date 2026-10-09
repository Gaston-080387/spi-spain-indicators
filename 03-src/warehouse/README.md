# Warehouse

T-SQL for `spi_warehouse`, run in the Warehouse SQL editor.

| File | Creates |
|---|---|
| `spi_gold_ddl.sql` | The star schema: `spi_dim_indicator`, `spi_dim_region`, `spi_dim_calendar`, `spi_dim_source` and `spi_fact_indicators`, with `NOT ENFORCED` keys. Seeds `spi_dim_source`, and the initial `spi_dim_region` rows. |
| `spi_log_table_ddl.sql` | `dbo.spi_log_pipeline_execution`, written by the pipelines' Script activities (ADR-009). |
| `spi_sp_gold_load.sql` | `dbo.spi_sp_gold_load` (`CREATE OR ALTER`): loads the fact for Energy, Construction and Tax from their Silver tables, delete-by-source then insert in one transaction (ADR-014). |

**Run order.**

1. `spi_gold_ddl.sql`, once.
2. `spi_log_table_ddl.sql`, once.
3. `spi_sp_gold_load.sql`, to create or change the procedure.

Before the procedure is executed, `spi_df_gold_dimensions` must have loaded
the dimensions, and the three Silver tables must be loaded. The procedure only
looks dimension keys up. It never writes to a dimension.

**Dimension ownership** (ADR-010, addendum 2026-10-06). `spi_dim_source` is
owned by `spi_gold_ddl.sql`. `spi_dim_region`, `spi_dim_calendar` and
`spi_dim_indicator` are owned by `spi_df_gold_dimensions`, which refreshes
them with Replace. The DDL `INSERT` into `spi_dim_region` is the initial seed
only: every dataflow refresh overwrites it, so region rows are changed in the
dataflow.
