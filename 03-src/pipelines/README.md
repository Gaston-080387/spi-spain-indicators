# Data Pipelines

Fabric Data Pipelines, one JSON definition per pipeline.

## Per-source pipelines

| File | Layer | Source | Runs | Logging |
|---|---|---|---|---|
| `spi_pl_bronze_ipc.json` | Bronze | IPC | `cp_ipc`: Copy, INE CSV over HTTP → `spi_bronze_ipc_raw` | `scr_log_ipc` |
| `spi_pl_bronze_ipi.json` | Bronze | IPI | `cp_ipi`: Copy, Azure SQL `staging_ipi_raw` → `spi_bronze_ipi_raw` | `scr_log_ipi` |
| `spi_pl_bronze_energy.json` | Bronze | Energy | `nb_bronze_energy`: `spi_nb_bronze_energy` | `scr_log_energy` |
| `spi_pl_bronze_construction.json` | Bronze | Construction | `nb_bronze_construction`: `spi_nb_bronze_construction` | `scr_log_construction` |
| `spi_pl_bronze_tax.json` | Bronze | Tax | `nb_bronze_tax`: `spi_nb_bronze_tax` | `scr_log_tax` |
| `spi_pl_silver_ipc.json` | Silver | IPC | `df_silver_ipc`: Dataflow `spi_df_silver_ipc` | `scr_log_silver_ipc` |
| `spi_pl_silver_ipi.json` | Silver | IPI | `df_silver_ipi`: Dataflow `spi_df_silver_ipi` | `scr_log_silver_ipi` |
| `spi_pl_silver_energy.json` | Silver | Energy | `nb_silver_energy`: `spi_nb_silver_energy` | `scr_log_silver_energy` |
| `spi_pl_silver_construction.json` | Silver | Construction | `nb_silver_construction`: `spi_nb_silver_construction` | `scr_log_silver_construction` |
| `spi_pl_silver_tax.json` | Silver | Tax | `nb_silver_tax`: `spi_nb_silver_tax` | `scr_log_silver_tax` |

**Logging.** Each per-source pipeline has one Copy, Notebook or Dataflow
activity, followed by a Script activity chained **On completion**. The Script
activity writes one row to `spi_warehouse.dbo.spi_log_pipeline_execution`, on
success and on failure (ADR-009, 2026-09-30 addendum). `run_id` is the `run_id`
parameter when it is passed, otherwise the pipeline's own RunId (ADR-009,
2026-08-28 amendment). The IPC and IPI Silver dataflows log `rows_processed`
as `NULL` (ADR-018, addendum 2026-10-14).

## Layer pipelines

| File | Layer | Runs | Gate |
|---|---|---|---|
| `spi_pl_bronze.json` | Bronze | `inv_bronze_ipc` → `_ipi` → `_energy` → `_construction` → `_tax`: Invoke pipeline (Legacy) | `lkp_gate_bronze`, `if_gate_bronze`, `fail_gate_bronze` (`GATE_BRONZE`) |
| `spi_pl_silver.json` | Silver | `inv_silver_ipc` → `_ipi` → `_energy` → `_construction` → `_tax`: Invoke pipeline (Legacy) | `lkp_gate_silver`, `if_gate_silver`, `fail_gate_silver` (`GATE_SILVER`) |
| `spi_pl_gold.json` | Gold | IPC and IPI: DELETE by `source_key`, Gold dataflow, log. Then `nb_gold_refresh_sql_endpoint` → `scr_gold_load` (`EXEC dbo.spi_sp_gold_load`) → `scr_log_gold_proc` | `lkp_gate_gold`, `if_gate_gold`, `fail_gate_gold` (`GATE_GOLD`) |

Activities are chained **On completion**; the gate's If Condition runs
**On success** of its Lookup (ADR-018). Each layer pipeline declares `run_id`
and passes it down, so one run logs one `run_id`.

**Gate.** A Lookup counts the layer's log rows for the current `run_id`. The
Fail activity fails the run if fewer than 5 sources logged, or any row is
`failed` or `running`, and names the failed sources (ADR-018 Decision 5).

**`spi_pl_bronze` and `spi_pl_silver`** invoke the per-source pipelines above
(ADR-018 Decision 1). A child pipeline's status is not a failure signal; the
log and the gate are (ADR-018, validation 2026-10-13).

**`spi_pl_gold` is flat**: it has no per-source pipelines and holds the
activities directly. It writes the log rows itself: one each for IPC and IPI,
and three (energy, construction, tax) for the procedure, which loads those
sources in one call. A row is `success` only if both activities behind it
succeeded: the DELETE and the dataflow, or the SQL endpoint refresh and the
procedure (ADR-018, addendum and validation 2026-10-15).

## Master pipeline

| File | Runs | Gate |
|---|---|---|
| `spi_pl_master.json` | `inv_bronze` → `inv_silver` → `inv_gold`: Invoke pipeline (Legacy), Wait on completion | None |

The activities are chained **On success** (ADR-018 Decision 2). Each one
passes `run_id = @pipeline().RunId`, so a master run logs a single `run_id`
across all three layers (ADR-018 Decision 3). The master writes no log rows
and has no gate. Each layer gate fails its own pipeline, and the next
On-success link does not run.

**How the files are produced.** Exported from Fabric: in the pipeline editor,
open **Edit JSON code** and copy its content into the file. Re-export after
any change made in Fabric.

`spi_pl_gold.json` was first generated from the Sprint 7 build sheet and
pasted into Fabric; the file is now the Fabric export (2026-10-15).

`spi_pl_master.json` was first generated and pasted into Fabric; the file is
now the Fabric export (2026-10-16).
