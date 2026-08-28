# Architecture Decision Records — SPI (Sector Performance Indicators)

**Solution / stack:** Microsoft Fabric · Lakehouse · Warehouse · Dataflows Gen2 · Notebooks (PySpark / Python) · Power BI (Direct Lake)
**Project:** SPI — public-data analytics platform (Spain indicators)
**Status:** Living document — maintained through Phase 5 development
**Confidential — Portfolio project — Not for distribution**

---

## Purpose and governance

The Phase 0–4 documents are frozen. They record the state of the design at the close of
each phase and are not edited retroactively. Decisions that arise during Phase 5
development — refinements, corrections, and deliberate deviations from the frozen
specification — are recorded here instead, so the specification and the reasoning remain
separately traceable.

Each record follows a MADR-lite structure: context, decision, alternatives considered,
and consequences. A record is `Accepted` once ratified and implemented; superseded
records are marked and cross-referenced, never deleted. Object names, code, and paths
appear in `monospace` exactly as they exist in the system. Facts without a source of
truth are marked `[TBC: …]` and listed in the delivery note.

| ADR | Title | Status | Primarily affects |
|-----|-------|--------|-------------------|
| 001 | Local Python scripts scoped to Bronze-equivalent ingestion | Accepted | Validation strategy, Sprints 5–6 |
| 002 | Derived measures as DAX time-intelligence, not materialized fact rows | Accepted | Gold model, semantic model |
| 003 | INE base index only in the star; official variations retained in Bronze | Accepted | Silver logic, DAX measures |
| 004 | `VARCHAR` over `NVARCHAR` for all persisted Warehouse columns | Accepted | Gold DDL |
| 005 | Last run ordered by start_time | Accepted | Source ingestion |
| 006 | Capacity region and SKU decision | Accepted | Capacity strategy |
| 007 | Bronze ingestion orchestation | Accepted | Bronze pipeline |
| 008 | Warehouse collation: case-insensitive  | Accepted | Gold layer |
| 009 | Logging: target, write mechanisms and status model | Accepted | Infraestructure |

---

## ADR-001 — Local Python scripts scoped to Bronze-equivalent ingestion

**Status:** Accepted · 2026-07-01 · Sprint 3

**Context.** Sprints 1–2 produced local Python scripts (`pandas`, `openpyxl`, `xlrd`,
`requests`) to de-risk the five sources before cloud development, together with Parquet
snapshots of their output. The scripts implement ingestion, error control, logging, and
metadata only; they perform no transformation. The medallion layer that these prototypes
and snapshots represent must be fixed, because it determines how they are used downstream.

**Decision.** The local scripts are prototypes of the Bronze notebooks. Their Parquet
snapshots are Bronze extraction baselines, not Silver baselines. The mapping is
deliberate: local scope (ingest, control, log, metadata; no business logic) is exactly
the Bronze definition.

**Alternatives considered.**
- Treat the local output as a Silver baseline. Rejected: it would require transforming
  twice — once in local `pandas`, once in cloud PySpark — which does not port 1:1 across
  the two APIs and blurs the Bronze/Silver boundary.
- Skip local validation. Rejected: the expensive risk is source-specific and structural
  (merged cells in the XLS, crosstab unpivot in the XLSX, API pagination, encoding). It
  is cheaper to resolve locally than mixed with cloud runtime and compute cost.

**Consequences.**
- Sprint 5 reconciliation (Bronze notebook output vs. local Parquet) is apples-to-apples.
- Silver has no local baseline. Silver validation in Sprint 6 runs against source totals,
  geographic-filter cardinality (three regions), and spot-checks — not against Parquet.
  Recorded here so it is planned rather than improvised.
- The frozen `phase5_dev_plan.md` describes the local step as producing "the expected
  transformation result" and "column transformations applied". That wording no longer
  matches the scripts' scope. The correction lives in this record; the phase document is
  not edited. `[TBC: align the repository README / dev-plan summary to "Bronze extraction
  baseline" at its next revision.]`

---

## ADR-002 — Derived measures as DAX time-intelligence, not materialized fact rows

**Status:** Accepted · 2026-07-01 · Sprint 3

**Context.** Phase 4 §4 models the four derived measures (YoY, MoM, YTD, QTD) as
additional fact rows selected through a `spi_dim_measure` dimension. This pattern was
carried over from the author's on-premise production system for the Comunidad de Murcia
(Microsoft stack, 80+ sources), where the same five measures are always required per
source. The same per-source requirement holds in SPI: the final Power BI report needs the
five measures for each of the five sources.

**Decision.** In SPI the derived measures are implemented as DAX time-intelligence over
`spi_dim_calendar` and `indicator_value`. `spi_dim_measure` and `fact.measure_key` are
removed; the fact stores only the base index. The per-source requirement is met by DAX:
the four derivations are defined once and apply uniformly to any source the report
filters, so all five measures remain available for every source without being stored.

**Alternatives considered.**
- Keep materialization, as in Murcia. This is the correct choice *for Murcia* and is
  retained there. Its justification is multi-surface consumption: the same measures are
  served to Power BI **and** to a web/API layer, so precomputing them in the fact makes
  them tool-agnostic and guarantees an identical YoY across every consumer; at 80+
  governed sources the case is stronger still. That driver does not exist in SPI. Gold is
  consumed by a single surface — Power BI via Direct Lake — with no web or API over Gold.
  With the driver removed, only the costs of materialization remain: a fact multiplied ×5
  (dead weight against Direct Lake's columnar paging); calculation logic baked into ETL
  (a change to the YTD definition would force pipeline edits and a backfill instead of a
  measure edit); and the aggregation risk of summing across measure types. Rejected for
  SPI on that basis.

**Consequences.**
- Fact grain drops from five dimensions to four. Implemented in
  `03-src/warehouse/spi_gold_ddl.sql`.
- `indicator_value` becomes `NOT NULL`. The `NULL` allowance in the frozen DDL existed
  only for derived-measure rows, which no longer exist; a base-index row without a value
  is not meaningful (a missing period is simply an absent row).
- DAX implementation note: standard time-intelligence expects a contiguous date table.
  `spi_dim_calendar` is monthly, so it gains a `date` column (first day of the month)
  marked as the model's date table. See ADR-003 for the non-additivity constraint on
  these measures.
- Portfolio rationale: the decision is documented with the Murcia-versus-SPI contrast
  because the contrast *is* the justification. Knowing both patterns and selecting per
  context is the distinction being demonstrated. This is intentional.

---

## ADR-003 — INE base index only in the star; official variations retained in Bronze

**Status:** Accepted · 2026-07-01 · Sprint 3

**Context.** The INE files (IPC, IPI) ship four measures per series: the base index plus
three official variations. The other three sources (Energy, Construction, Tax) ship a
single value. A uniform grain across the five sources requires a single base measure
(see ADR-002).

**Decision.** Silver isolates the base-index row; only it reaches the star schema. The
three official INE variations are not discarded: Bronze retains them (Bronze stores
source data as received), and they serve as a reconciliation baseline — the
DAX-computed derivations are validated against INE's official published figures.

**Alternatives considered.**
- Load all four INE measures. Rejected: it reintroduces the heterogeneity ADR-002
  removes — one measure stored as data for INE, computed as DAX for the rest — a
  two-mechanism model that a reviewer would question.
- Discard the variations entirely. Rejected: they are free, authoritative validation
  data from the issuing institution.

**Consequences.**
- The Silver filter is row-based, not column-based: the four measures arrive stacked,
  distinguished by a series-metadata column. Post-filter cardinality check:
  `silver_rows = periods × regions × 1`.
- Non-additivity constraint. An index is not additive, so `DATESYTD` / `TOTALYTD` with
  SUM semantics produce incorrect results. The derivations are ratios
  (`variation = index_t / index_(t-n) − 1`) and INE's specific accumulations
  (year-to-date compares the current month against December of the prior year). Each DAX
  measure states this semantics explicitly. This constraint applies to all five sources,
  not only INE.
- The Bronze-vs-official reconciliation is itself a portfolio artifact: it shows computed
  logic checked against the source authority rather than trusted blindly.
  `[TBC: record the reconciliation outcome once Silver and Gold are built in Sprint 6.]`

---

## ADR-004 — `VARCHAR` over `NVARCHAR` for all persisted Warehouse columns

**Status:** Accepted · 2026-07-01 · Sprint 3

**Context.** Phase 4 §4 writes the Gold DDL entirely in `NVARCHAR`. Fabric Warehouse does
not support `NVARCHAR` for persisted table columns.

**Decision.** All persisted string columns use `VARCHAR` under the Warehouse default
collation `Latin1_General_100_BIN2_UTF8` (UTF-8), which stores Unicode natively — for
example `Cataluña` in `region_name`. Implemented in
`03-src/warehouse/spi_gold_ddl.sql`.

**Evidence.** Microsoft Learn — *Data types in Fabric Data Warehouse*: `nvarchar`,
`nchar`, and `ntext` are unsupported for persisted objects; `varchar` with a UTF-8
collation is the supported Unicode string type.

**Alternatives considered.** None viable: `NVARCHAR` is unsupported for persisted
Warehouse tables. The frozen Phase 4 §4 DDL would fail at `CREATE TABLE` as written.

**Consequences.**
- Mechanical `NVARCHAR(n) → VARCHAR(n)` across the four dimensions and the fact table.
- No behavioral change for Unicode content under the UTF-8 collation.
- Reserved-word column names (`[year]`, `[month]`, `[quarter]`) are bracketed defensively.
- Related Fabric constraints applied in the same DDL, for completeness: `PRIMARY KEY` and
  `FOREIGN KEY` are declared `NONCLUSTERED … NOT ENFORCED` (Fabric does not enforce
  constraints; they document the model and enable Power BI relationship detection); and
  `IDENTITY` is not used (surrogate keys are assigned via seed inserts for fixed
  dimensions and programmatically for `spi_dim_calendar` and `spi_dim_indicator`).

---

## ADR-005 — Latest-run identification ordered by start_time

**Status:** Accepted · 2026-07-01 · Sprint 3

**Context.** Phase 4 §10.4 selects the latest run with `MAX(run_id)`, but
`run_id` is a GUID `STRING`. GUIDs are not monotonic, so `MAX(run_id)`
returns an arbitrary run, not the most recent one.

**Decision.** The latest run is the `run_id` of the row with the maximum
`start_time`. No schema change: `start_time` already exists.

**Alternatives considered.** Add a monotonic `run_seq` or a run-level
`run_started_at` column. Rejected for portfolio scope: `start_time` already
orders runs reliably without widening the table.

**Consequences.** The §10.4 diagnostic queries are corrected in
`03-src/lakehouse/spi_log_table_ddl.sql`. No impact on the helper, which
updates by `(run_id, pipeline_name)`.

---

## Pending — not yet ratified

- **Source seed values.** `spi_dim_source` is seeded with `update_frequency = 'Monthly'`
  for all five sources and `source_url = NULL`. `[TBC: confirm official source URLs for
  the final source catalog.]`

---

## ADR-006 — Fabric capacity: trial F4 in North Europe

**Date:** 2026-08-22
**Status:** Accepted

### Context

Fabric trial capacity became available after the 90-day tenant age
restriction lapsed. Activation offers a one-time region choice that
cannot be changed afterwards: relocating a workspace to a different
region requires deleting all non-Power BI Fabric items first.

Tenant home region is Spain Central (Madrid). Spain Central was not
offered in the trial capacity region dropdown. The dialog pre-selected
Australia East, which is neither the home region nor a viable choice
from Spain.

The Azure SQL Database source is hosted in North Europe.

Trial capacity was provisioned at F4 (4 CUs). No resize option is
exposed for this tenant.

Capacity: `Trial-20260821T221247Z-…` (full identifier in `99-private/`)
Activated 2026-08-21, expires 2026-10-20.

### Decision

Deploy trial capacity in **North Europe**, accepting a split between
tenant home region (Spain Central) and capacity region (North Europe).

### Rationale

- Co-locates compute with the Azure SQL source, avoiding cross-region
  transfer on the highest-volume ingestion path.
- North Europe supports all Fabric workloads required by SPI.
- EU data residency is maintained for Spanish public sector data.
- Latency from Barcelona (~35-45 ms) is acceptable for development.

### Consequences

- Multi-geo configuration: tenant-level storage remains in Spain
  Central; SPI workspace content resides in North Europe. Items
  requiring availability in both regions (e.g. Fabric SQL Database)
  are excluded from scope. Warehouse is used instead.
- F4 provides 8 Spark vCores. Ingestion of the five sources must be
  sequenced rather than parallelised. See ADR-007 (orchestration order).
- Default Medium starter pool sessions exceed the available vCores;
  Spark autoscale must be pinned to 1 node.
- All Fabric items must be reproducible from the repository so that
  capacity lapse costs time, not work. F2 pay-as-you-go identified
  as fallback.

### Notes

Warehouse and SQL analytics endpoint CU consumption calculations
changed in August 2026. Cost baselines must be measured on this
capacity, not taken from external sources.

---

## ADR-007 — Bronze ingestion orchestration: order, dependencies and logging

**Date:** 2026-08-24
**Status:** Accepted

### Context

`spi_pl_bronze` ingests five independent public data sources into the
Bronze layer. No source depends on the output of any other. The pipeline
must therefore decide execution order, failure semantics between
sources, and how each source records its outcome.

Capacity is F4 (see ADR-006), providing 8 Spark vCores with autoscale
pinned to a single node. The three notebook activities contend for this
resource; the two Copy Activities do not consume Spark.

Phase 1 catalogues the sources in ascending order of ingestion
complexity. Phase 2 specifies the Bronze ingestion tool per source.

### Decision

**Execution order** (linear chain, complexity-ascending):

| # | Source | Bronze ingestion tool | Format |
|---|--------------|------------------------------|-------------------|
| 1 | IPC (INE) | Pipeline — Copy Activity | CSV (HTTP) |
| 2 | IPI (INE) | Pipeline — Copy Activity | Azure SQL |
| 3 | Energy (REE) | Notebook (Python) | REST API / JSON |
| 4 | Construction | Notebook (Python) | 4 × legacy XLS |
| 5 | Tax (AEAT) | Notebook (Python) | XLSX, multi-sheet |
| 6 | Log gate | Lookup + If Condition + Fail | — |

**Dependency semantics:**

- Activities 1→5 are chained **On completion**. A failure in one source
  does not prevent subsequent sources from attempting ingestion.
- Layer transitions in `spi_pl_master` (Bronze → Silver → Gold) remain
  **On success**. Transforming un-ingested data is worse than not
  running.

**Logging:**

- Sources 3–5 (notebooks) log their own outcome via `spi_logging.py`.
- Sources 1–2 (Copy Activities) cannot execute Python. Each is followed
  by a **Script activity** issuing T-SQL against the log table.
- Activity 6 reads the log for the current run and **fails the pipeline
  deliberately** if any source reported failure.

### Rationale

- **Complexity-ascending order enables fail-fast.** Configuration
  problems with the workspace, capacity or Lakehouse surface while
  ingesting a plain CSV, not while debugging merged cells in `xlrd`.
- **On completion reflects the domain.** The sources are genuinely
  independent; a REE API outage should not block Tax ingestion.
- **Activity 6 is required, not optional.** With every activity chained
  on completion, a pipeline whose third source failed reports
  *Succeeded*. Green pipeline with missing data is a silent failure.
  The log gate restores truthful run status while preserving partial
  execution.
- **Script activities keep logging co-located with the source.** Each
  source records its own outcome at the moment it occurs, consistent
  with notebook behaviour. The alternative — deriving sources 1–2
  outcomes from pipeline expressions inside activity 6 — produces no
  record at all if the pipeline dies before reaching it.

### Alternatives considered

**Parallel execution of activities 1 and 2.** IPC and IPI are Copy
Activities and do not contend for Spark vCores, so they could run
concurrently. Deferred: expected saving is under one minute, while
cold Spark session startup across three sequential notebooks is the
dominant cost on F4. Revisit after the step-8 baseline measurement
quantifies actual runtimes. Spark session reuse across notebook
activities is the higher-value optimisation to investigate at that
point.

### Consequences

- Pipeline contains 8 activities: 2 Copy + 2 Script + 3 Notebook +
  1 log gate (gate expands to Lookup, If Condition, Fail).
- Partial ingestion is a supported outcome. Downstream Silver
  processing must tolerate a Bronze table being stale rather than
  assuming all five refreshed together.
- The log table becomes load-bearing: it is the only record of what
  actually ran. Its DDL is already committed
  (`spi_log_table_ddl.sql`).
- Three sequential cold Spark sessions per run. Accepted for now,
  measured at step 8.

### Addendum — 2026-08-26: measured baseline

The rationale above assumed cold Spark session startup was the dominant
runtime cost. Measurement contradicts this: session attach was ~5 seconds
on the Starter pool, not minutes. That argument for deferring parallel
execution of activities 1 and 2 does not hold.

A stronger constraint was measured in its place. A single Spark session
consumed 1,375.95 CU-seconds over 343.98 seconds of session lifetime —
4.0 CU per second, the full FTL4 allocation, held continuously for as
long as the session is alive regardless of whether it is computing.

Consequences for this ADR:

- Sequential execution of activities 3–5 is not a prudential choice but
  a capacity constraint: two concurrent Spark sessions would require
  8 CU against an available 4.
- High concurrency mode is enabled at workspace level, allowing notebook
  activities within a pipeline to share one session. Whether this applies
  to the three Bronze notebooks is unverified and should be tested at
  step 8; if it works, the three notebooks cost one session rather than
  three.
- Deferral of parallel execution for activities 1 and 2 stands, but on
  the grounds of measuring before optimising rather than on session
  startup cost.
- Warehouse operations consumed 3,011 CU-seconds during DDL execution,
  more than the notebook session. Warehouse activity is not negligible
  on this capacity.

Decision unchanged.

### Addendum — 2026-08-28: constraint restated after first pipeline run

The 2026-08-26 addendum established that a Spark session consumes
4.0 CU/second. First end-to-end pipeline execution (IPC Bronze
ingestion, 331,520 rows) allows the constraint to be stated precisely.

Measured, full day of activity including DDL work, interactive queries
and the pipeline run:

| Item | CU-seconds |
|-------------------|------------|
| spi_warehouse | 1,694.93 |
| spi_lakehouse | 198.64 |
| **Total** | **1,893.58** |

Daily capacity budget at FTL4: 4 CU x 86,400 s = 345,600 CU-seconds.
Consumption represents 0.55% of one day. Average utilisation 0.38%,
peak 1.18%, zero throttling and zero rejections.

**The constraint is instantaneous concurrency, not daily volume.**
Two concurrent Spark sessions each require the full 4 CU at the same
moment and cannot coexist. Total consumption over a day is negligible;
the full five-source pipeline is expected to remain within a few
percent of the daily budget and could run many times per day without
approaching the ceiling.

Sequential execution of activities 3-5 therefore stands, but the
justification is the instantaneous CU ceiling — not capacity scarcity.
The earlier framing ("capacity is tight") is inaccurate and should not
be used in defense of this decision.

Note: item-level figures are daily aggregates and include interactive
development queries. Per-activity attribution requires the Operations
tab or TimePoint drill-through; not isolated at time of writing.

Decision unchanged.

## ADR-008 — Warehouse collation: case-insensitive

**Date:** 2026-08-26
**Status:** Accepted

### Context

Fabric Warehouse defaults to `Latin1_General_100_BIN2_UTF8`, a binary
case-sensitive collation. This differs from SQL Server and Azure SQL
Database, where case-insensitive collations are the conventional
default.

Collation is fixed at warehouse creation and cannot be altered
afterwards. Changing it requires creating a new warehouse and
migrating all objects and data.

SPI conforms geographic and indicator attributes across five
independent Spanish public data sources (INE, REE, MITMA, AEAT), each
with its own capitalisation conventions for region names and category
labels.

### Decision

Set the workspace collation to
`Latin1_General_100_CI_AS_KS_WS_SC_UTF8` before creating
`spi_warehouse`, so the warehouse inherits it at creation.

Case-insensitive, accent-sensitive.

### Rationale

- **Cross-source conformance.** Under a case-sensitive collation,
  `'Cataluña'` and `'CATALUÑA'` are distinct values. Every
  capitalisation inconsistency between sources becomes a silently
  failed join in the Gold layer — a data quality defect that produces
  no error, only missing rows.
- **Accent sensitivity retained.** The `AS` component means `'Cataluña'`
  and `'Cataluna'` remain distinct. This is intended: the objective is
  normalising case, not stripping diacritics from Spanish place names.
- **Consistency with the author's SQL Server background** and with the
  conventions of the Azure SQL source system, reducing the risk of
  case-related defects introduced by habit.
- **Object name resilience.** `dbo.spi_dim_region` and
  `dbo.Spi_Dim_Region` resolve identically, removing a class of
  avoidable errors across DDL, notebooks, Dataflows and DAX.

### Alternatives considered

**Accept the `BIN2_UTF8` default.** Binary collation offers more
efficient string filtering and sorting over Parquet. Rejected: the
performance advantage is irrelevant at SPI's data volumes (fact table
estimated ~360,000 rows before the ADR-002 measure reduction), while
the join-correctness risk is material and manifests silently.

### Consequences

- Slightly less efficient string comparison in the Warehouse. Not
  measurable at this scale.
- **Applies to the Warehouse only.** Spark string comparisons in the
  Lakehouse remain case-sensitive regardless of this setting.
  Case normalisation of dimension attributes therefore still belongs
  in the Silver layer; this collation is a safety net for the Gold
  join, not a substitute for cleansing.
- Irreversible for `spi_warehouse`. Any future warehouse created in
  this workspace inherits the same collation unless the workspace
  setting is changed first.
- The PROD warehouse created in Sprint 8 must be created in a
  workspace with the same collation setting, or DEV and PROD will
  diverge in join behaviour. Verify before creating PROD.

## ADR-009 — Logging: target, write mechanisms and status model

**Date:** 2026-08-27
**Status:** Accepted

### Context

ADR-007 specifies a Script activity issuing T-SQL after each Copy
Activity, and a log gate that reads the log table to determine whether
the pipeline should fail. Phase 4 §2.3.3 places the logging table in
`spi_lakehouse`.

These are incompatible. A Lakehouse's SQL analytics endpoint is
read-only; T-SQL cannot INSERT into a Lakehouse Delta table. One of
the two specifications has to move.

The Spark connector for Fabric Data Warehouse supports writes from
PySpark on Runtime 1.3, but writes in two phases — staging the
DataFrame to intermediate storage, then COPY INTO the target table.

### Decision

The log table is `spi_warehouse.dbo.spi_log_pipeline_execution`.

Write paths by execution context:

| Component | Mechanism |
|-----------------------------|--------------------------------------------|
| Copy Activities (IPC, IPI) | Script activity → T-SQL INSERT/UPDATE |
| Notebooks (Energy, Constr., Tax) | `notebookutils.data.connect_to_artifact()` |
| Log gate | Lookup + If Condition + Fail |

**Status model — two-phase.** Each step INSERTs with
`status = 'running'` on entry, then UPDATEs to `success` or `failed`
on exit. `run_id` is the master pipeline GUID (`@pipeline().RunId`),
propagated to all children, correlating every row from one execution.

### Rationale

- **Single log target.** One table, queried by one log gate. Splitting
  the log across Lakehouse and Warehouse would require the gate to
  read from two places and reconcile them.
- **Each write path is native to its context.** Script activities
  already speak T-SQL. Notebooks get a direct SQL connection without
  leaving Python.
- **`synapsesql()` rejected for logging.** Two-phase staging plus
  COPY INTO is disproportionate for single-row inserts. It remains
  the correct choice for bulk DataFrame writes if Gold loading needs
  one.
- **Two-phase status gives execution visibility.** An orphaned
  `running` row is diagnostic evidence: the step started and died
  without exiting cleanly. A single insert-on-completion design
  cannot distinguish "crashed" from "never started".

### Alternatives considered

**Log table in Lakehouse, Notebook activity for Copy Activity
logging.** Rejected. A Spark session consumes 4.0 CU/second — the
full FTL4 allocation (see ADR-007 addendum). Starting a session to
write two log rows is not justifiable.

**Single INSERT at completion.** Simpler and halves the round trips,
but loses in-flight visibility and cannot distinguish a crash from a
step that never ran. Rejected.

### Consequences

- **Supersedes Phase 4 §2.3.3** regarding log table location. The
  Lakehouse continues to hold Bronze and Silver Delta tables.
- `spi_logging.py` retains the interface specified in Phase 4 §10;
  only its internals change from a Delta write to a Warehouse
  connection.
- **The log gate must treat `running` as a failure state.** Otherwise
  a crashed notebook leaves a row that is neither `success` nor
  `failed`, and the gate passes it silently — reintroducing exactly
  the green-pipeline/missing-data problem ADR-007 exists to prevent.
- Every logging call is two round trips against the Warehouse.
  Warehouse operations are not free on FTL4 (~3,011 CU-s observed
  during DDL execution); the cost of ~20 log writes per run should be
  measured at step 8.
- Notebook write path depends on `notebookutils.data` being available
  in Runtime 1.3, and on its authentication behaviour under
  pipeline-triggered execution rather than interactive sessions.
  Unverified at time of writing.

### Notes — Fabric Warehouse T-SQL findings

Encountered while implementing the log table DDL:

- `TIMESTAMP` is not a date/time type in T-SQL; it is a deprecated
  synonym for `ROWVERSION`, and only one is permitted per table.
  Use `DATETIME2(6)` — Fabric caps datetime2 precision at 6 digits,
  not SQL Server's 7.
- `VARCHAR` without an explicit length silently defaults to
  `VARCHAR(1)`. Lengths must always be stated explicitly.

### Amendment — 2026-08-28: asymmetric status model

The original decision specified two-phase logging (INSERT 'running',
then UPDATE) uniformly across all sources. Implementation of the IPC
Copy Activity established that this is not appropriate for
pipeline-native activities.

**Revised decision.**

| Component | Status model |
|------------------------|--------------------------------------|
| Copy Activities | Single-phase: one INSERT after completion |
| Notebooks | Two-phase: INSERT 'running', UPDATE on exit |

**Rationale — failure mode, not convenience.**

A notebook controls its own error handling and can update its row to
'failed' via try/except. What it cannot catch is a hard termination:
session loss, out-of-memory, capacity throttling. The orphaned
'running' row is the only evidence such a failure occurred.

A Copy Activity cannot self-report. The pipeline logs on its behalf
via a Script activity chained On completion, reading
`activity('cp_<source>').Status`. A pre-insert would only record that
the preceding Script ran — information already visible in the
monitoring view.

The gate's completeness check (`sources_logged < 5`) already covers
the residual case: a Copy Activity failing without its Script
executing produces no log row, which fails the pipeline. The
'running' row is therefore redundant for correctness in this path and
diagnostically least useful where it is cheapest to omit.

**Implementation note.** Pipeline parameter defaults must be literals,
so `run_id` cannot default to `@pipeline().RunId`. Both the Script
activities and the log gate use:

    @{if(empty(pipeline().parameters.run_id),
         pipeline().RunId,
         pipeline().parameters.run_id)}

Standalone runs log their own RunId; runs invoked by `spi_pl_master`
log the master's, preserving correlation across child pipelines.