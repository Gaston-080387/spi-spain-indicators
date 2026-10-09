# Data Pipelines

Fabric Data Pipelines, one JSON definition per pipeline.

| File | Layer | Source | Runs | Logging |
|---|---|---|---|---|
| `spi_pl_bronze_ipc.json` | Bronze | IPC | `cp_ipc`: Copy, INE CSV over HTTP → `spi_bronze_ipc_raw` | `scr_log_ipc` |
| `spi_pl_bronze_ipi.json` | Bronze | IPI | `cp_ipi`: Copy, Azure SQL `staging_ipi_raw` → `spi_bronze_ipi_raw` | `scr_log_ipi` |
| `spi_pl_bronze_energy.json` | Bronze | Energy | `nb_bronze_energy`: `spi_nb_bronze_energy` | `scr_log_energy` |
| `spi_pl_bronze_construction.json` | Bronze | Construction | `nb_bronze_construction`: `spi_nb_bronze_construction` | `scr_log_construction` |
| `spi_pl_bronze_tax.json` | Bronze | Tax | `nb_bronze_tax`: `spi_nb_bronze_tax` | `scr_log_tax` |
| `spi_pl_silver_energy.json` | Silver | Energy | `nb_silver_energy`: `spi_nb_silver_energy` | `scr_log_silver_energy` |
| `spi_pl_silver_construction.json` | Silver | Construction | `nb_silver_construction`: `spi_nb_silver_construction` | `scr_log_silver_construction` |
| `spi_pl_silver_tax.json` | Silver | Tax | `nb_silver_tax`: `spi_nb_silver_tax` | `scr_log_silver_tax` |

**Logging.** Each pipeline has one Copy or Notebook activity, followed by a
Script activity chained **On completion**. The Script activity writes one row
to `spi_warehouse.dbo.spi_log_pipeline_execution`, on success and on failure
(ADR-009, 2026-09-30 addendum). `run_id` is the `run_id` parameter when it is
passed, otherwise the pipeline's own RunId (ADR-009, 2026-08-28 amendment).

IPC and IPI Silver and Gold run as Dataflows Gen2 (`../dataflows/`), not
pipelines.

**How the files are produced.** Exported from Fabric: in the pipeline editor,
open **Edit JSON code** and copy its content into the file. Re-export after
any change made in Fabric.
