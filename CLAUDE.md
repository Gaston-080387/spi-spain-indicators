# CLAUDE.md

Standing context for Claude Code sessions in this repository.

## Project

**SPI — Spain Public Indicators.** An end-to-end analytics platform on
Microsoft Fabric ingesting five Spanish public data sources into a
medallion architecture (Bronze → Silver → Gold), surfaced as a star
schema in a Fabric Warehouse and a Power BI report over Direct Lake.

Sources, in ingestion order (ascending complexity):

| # | Source | Origin | Bronze mechanism |
|---|--------------|-------------------|--------------------------|
| 1 | IPC | INE, CSV over HTTP | Pipeline Copy Activity |
| 2 | IPI | Azure SQL (staging) | Pipeline Copy Activity |
| 3 | Energy | REE REST API | Notebook (Python) |
| 4 | Construction | MITMA, 4 legacy XLS | Notebook (Python) |
| 5 | Tax | AEAT, multi-sheet XLSX | Notebook (Python) |

This is a portfolio project. Its purpose is to demonstrate senior data
engineering judgment to prospective freelance clients — the reasoning
is the deliverable as much as the code.

## Current state

**Sprint 3 (Fabric environment setup) — closed 2026-09-10.**

Trial capacity activated and configured, workspace provisioned,
Lakehouse and Warehouse created, Gold DDL and log table DDL executed,
Azure SQL connection created and tested, PySpark primer and toy
notebook completed, defense rehearsal passed.

**Sprint 4 (IPC and IPI end-to-end via Dataflows Gen2) — closed
2026-09-29.** Defense rehearsal (S4-9) passed.

Both sources run Bronze → Silver → Gold:

| Source | Bronze pipeline | Silver / Gold dataflows | Gold rows |
|---|---|---|---|
| IPC | `spi_pl_bronze_ipc` | `spi_df_silver_ipc`, `spi_df_gold_ipc` | 12,390 |
| IPI | `spi_pl_bronze_ipi` | `spi_df_silver_ipi`, `spi_df_gold_ipi` | 8,379 |

Dimensions are seeded by `spi_df_gold_dimensions`. Fact loads use
delete-by-source then Append (ADR-010). Validated: Gold rows equal
Silver rows, zero null keys, zero duplicate composite keys.

**Deferred into Sprint 7** (need a pipeline around the dataflows):
the `DELETE … WHERE source_key` step before each Gold dataflow, and
logging for Silver and Gold dataflows. Until then the DELETE is run
manually before each Gold refresh.

**Sprint 7 notes:** `spi_dim_indicator.indicator_name` for IPC keys
1–13 contains a double space (`IPC -  Alimentos…`). Display only; not a
join key.

**Sprint 5 (Bronze notebooks: Energy, Construction, Tax) — closed
2026-10-03.** Three Bronze notebooks and pipelines
(`spi_nb_bronze_energy` / `_construction` / `_tax`,
`spi_pl_bronze_energy` / `_construction` / `_tax`) on the Fabric Python
runtime (ADR-012). Logging by Script activities in the pipelines
(ADR-009). Positional Bronze for the spreadsheet sources (ADR-013).

**Sprint 6 (Silver notebooks and Gold stored procedure) — next.** Three
Silver notebooks (Energy, Construction, Tax) on the Python runtime
(ADR-012 addendum, 2026-10-04) and the stored procedure
`dbo.spi_sp_gold_load` in `spi_warehouse`, which replaces the Gold
notebook (ADR-014), 7–13 October (`phase5_dev_plan.md` §2.1). Trial
expires ~2026-10-20; checkpoint 13 October.

**Unverified assumptions** worth checking before relying on them:
- Whether Direct Lake requires the Large semantic model storage format
  (workspace is currently set to Small).

Do not infer sprint status from commit history — it lags reality.
Ask if it matters.

## Governance model

**Phase documents (`01-docs/phase0`–`phase4`) are frozen.** They are
reference, not contract, and they are three months old. Where
implementation diverges, the phase document is not edited.

**`spi_adr_log.md` records every deviation and decision.** It is the
authoritative source for current design. When a phase document and an
ADR disagree, the ADR wins. ADRs are appended to, never rewritten —
corrections are dated addenda so the reasoning trail survives.

**`lessons-learned.md`** records platform findings (things discovered),
as distinct from decisions (things chosen, which are ADRs).

Several ADRs supersede specific phase-document sections. Check the ADR
log before treating any phase document as current.

**Never edit the frozen phase documents**, even when they contradict
current implementation. A contradiction between a phase document and
reality is not a defect to fix — it is a deviation, and it is recorded
in the ADR log. Correcting the phase document at source would destroy
the reasoning trail the ADR log exists to preserve. Surface such
contradictions; do not resolve them.

## Repository layout

```
01-docs/           Frozen phase deliverables, ADR log, dev plan, lessons learned
02-prerequisites/  One-time local Python bootstrap scripts (Phase 4.5 validation)
03-src/            Fabric productive code
  warehouse/       DDL
  notebooks/       Bronze notebooks for Energy, Construction and Tax
  pipelines/       Bronze pipelines for all five sources (exported JSON)
  dataflows/       Silver, Gold and dimension dataflows (exported M)
  power-bi/        (empty — Sprint 7)
99-private/        Gitignored. Source data, screenshots, personal journal
```

## Conventions

**Fabric items:** `spi_<type>_<layer>_<source>` — e.g.
`spi_pl_bronze_ipc`, `spi_nb_bronze_energy`, `spi_bronze_ipc_raw`.
The unsuffixed `spi_pl_bronze` is reserved for the master orchestration
pipeline (Sprint 7). Dataflows: `spi_df_<layer>_<source>`, plus
`spi_df_gold_dimensions`.

**Dimension keys:** assigned explicitly in `spi_df_gold_dimensions`,
never derived from source codes. `spi_dim_indicator` keys come from one
sequence across all sources (IPC 1–14, IPI from 15); its natural key is
`(indicator_category, domain)`. New indicator rows are added there, not
by the Gold notebook.

**Pipeline activities:** `cp_` Copy · `nb_` Notebook · `scr_` Script ·
`lkp_` Lookup · `if_` If Condition · `fail_` Fail.

**Commits:** `[sprint-id] short description` — e.g. `[S3] add log gate query`.

**Language:** all code, comments, documentation and commit messages in
English.

## Platform constraints

Discovered against this environment. They are not optional style
preferences — code that ignores them fails.

**Capacity is FTL4 (4 CU).** A Spark session consumes 4.0 CU/second for
its entire lifetime regardless of workload. Two concurrent Spark
sessions cannot coexist. Notebook execution is strictly sequential.
Daily consumption is nonetheless low (~0.5% observed) — the constraint
is instantaneous concurrency, not volume.

**Fabric Warehouse T-SQL:**
- `PRIMARY KEY` is rejected inside `CREATE TABLE`. Create the table,
  then `ALTER TABLE ... ADD CONSTRAINT ... NOT ENFORCED`.
- `TIMESTAMP` is not a date/time type — it is `ROWVERSION`. Use
  `DATETIME2(6)` (precision caps at 6, not 7).
- `VARCHAR` without an explicit length silently becomes `VARCHAR(1)`.
- No `IDENTITY`. Surrogate keys are assigned in load logic.
- Constraints are never enforced. Uniqueness is the load logic's
  responsibility.
- Collation is case-insensitive, accent-sensitive
  (`Latin1_General_100_CI_AS_KS_WS_SC_UTF8`).

**Lakehouse SQL analytics endpoint is read-only.** T-SQL cannot INSERT
into Lakehouse Delta tables. This is why the log table lives in the
Warehouse (ADR-009).

**Bronze notebooks write Delta through the OneLake `abfss://` URL**,
not `/lakehouse/default/Tables/`. The mounted path does not support the
file rename a Delta commit needs, so the write fails with
`Operation not permitted`. See `lessons-learned.md`, "Python notebooks".

**Bronze stores every field as string.** Type casting happens in Silver
where it can be validated and logged. Bronze rows carry
`_ingestion_timestamp` plus `_source_file` (file sources) or
`_source_table` (the Azure SQL source).

**The fact table is shared by all five sources.** Never load it with
Replace or truncate it: each source deletes only its own rows
(`WHERE source_key = n`), then appends (ADR-010).

## Working agreement

The author is a senior data analyst (SQL Server, SSIS, Power BI, ADF)
who is new to PySpark, Fabric, and Claude Code. He owns all design
decisions; the agent implements them.

- **Explain Fabric and PySpark concepts as they arise.** Do not assume
  prior knowledge of Spark, notebooks, or the Fabric item model.
- **YAGNI.** Build what the current sprint needs. Do not add
  abstraction, configuration, or error handling for cases that do not
  yet exist.
- **One task at a time, bounded.** Do not fix unrelated things noticed
  along the way — surface them and let the author decide.
- **Do not make architectural decisions.** If a task requires choosing
  between approaches, stop and ask. Design choices belong in the ADR
  log, made deliberately.
- **Flag uncertainty explicitly.** Fabric changes faster than training
  data. Say when something needs verifying against current docs rather
  than asserting it.
- **State the intended change before making it.** Even when the session
  permission mode would allow editing without a prompt, say which files
  will change and how, so the author can stop it before rather than
  review it after.
- **Never commit.** Leave changes staged or unstaged for review.
