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
| 010 | Gold load strategy for Dataflow sources: seeded dimensions, delete-by-source + append | Accepted | Gold fact load, Sprint 7 pipeline |
| 011 | Single workspace: no separate PROD environment | Accepted | Environment strategy |
| 012 | Bronze notebooks on the Fabric Python runtime | Accepted | Bronze notebooks, Sprint 5 |
| 013 | Construction Bronze stores the raw XLS grid | Accepted | Construction Bronze notebook, Sprint 6 Silver |

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

**Addendum — 2026-10-03: Reconciliation results.**
- **Energy (2026-09-30).** 457 rows in Fabric against 448 locally. All 36 region-year
  groups from 2014 to 2025 match exactly on row count and value sum. 2026 has more months
  in Fabric (local Parquet ingested 2026-06-20).
- **Construction.** See ADR-013, validation 2026-10-01 (+4 rows per file).
- **Tax.** See ADR-013, validation 2026-10-03 (+3 months).

**Conclusion.** The local baselines are older than the live sources, so reconciliation
compares structure and overlapping periods, not total row counts.

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

### Addendum — 2026-08-31: Azure SQL access model

Phase 4 §8.3 specifies least privilege (CREATE USER FROM EXTERNAL
PROVIDER + GRANT SELECT on the staging table). Not implemented: the
Fabric identity is already the Entra admin of spi-sqlserver-gb and
holds full access by default. The project operates with a single
identity; creating a second principal solely to demonstrate least
privilege was judged out of scope. In a client engagement, Fabric
would authenticate as a dedicated service principal with SELECT on
the source table only.

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

### Addendum — 2026-09-09: notebook write mechanism invalid

The decision specifies notebooks writing log rows via
`notebookutils.data.connect_to_artifact()`. That method does not exist
in Runtime 1.3, and no equivalent exists elsewhere in `notebookutils`
(see `lessons-learned.md`).

The Copy Activity path (Script activity → T-SQL) is unaffected and
remains valid. The notebook path requires a replacement mechanism.
Candidates: the Spark connector `synapsesql()` (rejected in the original
decision as disproportionate for single-row writes, but functional), or
relocating notebook logging outside the notebook — a Script activity
after each Notebook activity, reading the notebook's exit value.

Deferred to Sprint 5, where the first Bronze notebook provides a real
consumer to design against.

### Addendum — 2026-09-30: notebook logging resolved

**Decision.** Notebooks do not write log rows. Each Notebook activity is
followed by a Script activity, chained **On completion**, that writes
the log row with T-SQL. This is the same mechanism the Copy Activities
already use.

**Status model — now uniform single-phase.** The two-phase model for
notebooks (2026-08-28 amendment) existed because a notebook cannot
record its own hard termination. An external observer can: if the
session dies, the Notebook activity reports `Failed`, and the Script
activity still runs and records it. The `running` row is no longer
needed. All components log one row, after completion.

**Notebook contract.**

| Outcome | Notebook behaviour | Script activity reads |
|---|---|---|
| Success | `notebookutils.notebook.exit(json.dumps({...}))` with `rows_written` | `activity('nb_…').output.result.exitValue` |
| Failure | Raises. Never catches and exits cleanly | `activity('nb_…').Status`, `activity('nb_…').error.message` |

`notebookutils.notebook.exit()` is called outside any `try/except`,
because a broad `except Exception` can swallow it.

**Alternatives rejected.**

- **`synapsesql()`.** It appends DataFrames through staging plus COPY
  INTO. It cannot UPDATE, so it cannot implement the status model, and
  it pays the staging cost for a single row. It also requires a Spark
  session (see ADR-012).
- **Notebook self-logging through a direct SQL connection.** It is
  functional in principle, but it adds a second write path with
  unverified authentication under pipeline execution, while the Script
  path is already proven in Sprint 4.

**Consequences.**

- One log write mechanism for every component: Copy Activities,
  notebooks, and the Dataflows from Sprint 7 (ADR-010).
- `spi_logging.py` has no consumer. It is retired in a separate change.
- Interactive notebook runs do not log. This is intended: the log table
  records orchestrated runs.
- The gate's rule "treat `running` as failure" becomes unreachable, but
  it is kept as a defensive check.
- Supersedes the notebook row of the original decision table and the
  2026-08-28 asymmetric model.

### Validation — 2026-09-30

`spi_pl_bronze_energy`, run standalone.

| Run | Notebook activity | Script activity | Pipeline | Log `status` | `rows_processed` | `error_message` |
|---|---|---|---|---|---|---|
| Success | Succeeded | Succeeded | Succeeded | `success` | 457 | NULL |
| Failure (`START_YEAR = 'abc'`) | Failed | Succeeded | Failed | `failed` | NULL | Contains the `TypeError` |

The failure was forced with a base parameter of the wrong type (see
`lessons-learned.md`, Data Pipelines). In both runs the Script activity
ran On completion and recorded the outcome — the behaviour the
2026-09-30 addendum depends on.

## ADR-010 — Gold load strategy for Dataflow sources: seeded dimensions, delete-by-source + append

**Date:** 2026-09-28
**Status:** Accepted

### Context

All five sources converge into a single fact table,
`dbo.spi_fact_indicators`. IPC and IPI reach Gold through Dataflows
Gen2 (`spi_df_gold_ipc`, `spi_df_gold_ipi`); the other three sources
will reach it through a notebook in Sprint 6.

Three platform facts shape the load design:

- A Dataflow Gen2 destination offers only **Append** or **Replace**.
  Replace truncates the entire destination table, not the rows the
  dataflow produced.
- Fabric Warehouse constraints are declared `NOT ENFORCED`. Nothing in
  the Warehouse prevents duplicate rows on the fact's composite key.
- Phase 4 §6.3 specifies Append without addressing reruns, and Phase 4
  §6.1 specifies seeded dimensions without defining how keys are
  resolved.

### Decision

**1. Fact load: delete this source's rows, then Append.**

```sql
DELETE FROM dbo.spi_fact_indicators WHERE source_key = <n>;
```

followed by the source's Gold dataflow in Append mode. Each source owns
only its own rows. Reruns are idempotent, and a load of one source
never touches another.

**2. Dimensions are seeded, not derived from source data.**
`spi_df_gold_dimensions` defines region, source and indicator rows as
literal lists (Enter Data), and generates `spi_dim_calendar` in M from
2000-01 to December of the current year. Keys are assigned explicitly,
so rebuilding a dimension never changes an existing key.

**3. Fact keys are resolved by lookup, never by parsing source codes.**
Gold dataflows merge Silver against each dimension (Left outer) and take
the surrogate key from the match. `calendar_key` is computed as
`year * 100 + month`; `source_key` is a per-source constant.

**4. Silver speaks the dimension vocabulary.** Mapping source labels to
canonical dimension values (`13 Madrid, Comunidad de` → `Madrid`,
`Total Nacional` → `Nacional`) is each source's Silver responsibility.
Silver keeps source values otherwise intact; no codes are invented to
support a lookup technique.

**5. Indicator grain.** The natural key of `spi_dim_indicator` is
`(indicator_category, domain)`. IPC keeps all 14 ECOICOP groups
(`indicator_key` 1–14), not only the general index. IPI continues from
key 15. Keys are drawn from a single sequence across all sources.

### Rationale

- **Replace rejected.** It truncates the whole shared table: running
  any one source's Gold dataflow would erase all other sources.
- **Append alone rejected.** Not idempotent. Every rerun duplicates the
  source's rows, and the Warehouse will not stop it.
- **MERGE rejected.** Not available as a Dataflow destination mode, and
  unnecessary: each run reloads the source's full history, which also
  picks up revisions INE publishes to previous months.
- **Left outer join for lookups.** An unmatched value surfaces as a null
  key that validation detects. An inner join would drop the row
  silently. This caught a real defect: the hand-typed dimension row for
  ECOICOP group 04 contained a double space and failed to match the
  Silver value. INE's own label was correct.
- **Keeping all ECOICOP groups.** The category breakdown is the main
  analytical value of IPC (what drives inflation). The cost is modest:
  14 dimension rows instead of 1, and no schema change.

### Alternatives considered

**Keep only `Índice general` for IPC.** Simpler grain, consistent with
the single-series sources. Rejected: removes the most useful IPC
analysis.

**Derive keys from source codes** (the `13` in `13 Madrid, Comunidad
de`). Rejected: some labels carry no code (`Índice general`,
`Nacional`), it couples fact keys to one source's coding scheme, and
failures are silent.

### Consequences

- **Deferred to Sprint 7.** The `DELETE … WHERE source_key` step and
  Dataflow logging both require a pipeline around the dataflow. They
  will be implemented as Script activities in `spi_pl_gold` and
  `spi_pl_silver` (S7A-2, S7A-3). Until then, the DELETE is run
  manually before each Gold refresh.
- **Single owner of `spi_dim_indicator`.** Phase 4 §5 specifies
  `upsert_indicator_dim()` inside the Gold notebook. That would create a
  second writer for the dimension. Indicator rows for Energy,
  Construction and Tax are added to `spi_df_gold_dimensions` instead;
  the notebook only looks keys up. Revisit in Sprint 6.
- Hand-typed dimension values are a defect surface of their own. Any
  value that serves as a join key must be copied from the source data,
  not retyped.
- `spi_dim_calendar.is_current_year` is computed at refresh time and is
  only correct after the dimension dataflow runs in the new year.
- Supersedes Phase 4 §6.3 (Append without rerun handling) and Phase 4 §5
  `upsert_indicator_dim()`.

### Validation — 2026-09-28

| Source | Fact rows | Silver rows | Null keys | Duplicate composite keys |
|---|---|---|---|---|
| IPC (1) | 12,390 | 12,390 | 0 | 0 |
| IPI (2) | 8,379 | 8,379 | 0 | 0 |

IPC: 3 regions × 14 ECOICOP groups × 295 months (2002-01 to 2026-07).

## ADR-011 — Single workspace: no separate PROD environment

**Date:** 2026-09-29
**Status:** Accepted

### Context

Phase 2 §10 and Phase 4 §2.3.2 and §12 specify two workspaces:
`spi-spain-indicators-dev` (last 24 periods, active development) and
`spi-spain-indicators-prod` (full history, portfolio surface), with
artifacts promoted through a Fabric Deployment Pipeline and deployment
rules per environment.

The v1.1 replan (`phase5_dev_plan.md` §2.1) leaves ~84 h for an
estimated 92–132 h of remaining work before the trial expires
(~2026-10-20). Two further facts emerged during Sprint 4:

- Every Dataflow Gen2 hardcodes the DEV `workspaceId` and
  `lakehouseId` in its M code. Promotion would require confirming that
  deployment rules can rebind them, or editing each dataflow in PROD.
- The dataflows already load full history (IPC 2002–2026). The
  `data_scope = last_24_periods` parameter that justified a lighter DEV
  environment was never needed and is not implemented.

### Decision

Keep a single workspace, `spi-spain-indicators-dev`. At the end of
development it is reassigned to a paid F capacity in North Europe,
loaded with full history, and paused by default. No PROD workspace, no
Deployment Pipeline, no deployment rules.

The workspace keeps its current name. Renaming it would change the
names referenced in pipeline JSON and documentation for no functional
gain.

### Rationale

- **Saves ~8–10 h** (S8-1 to S8-4 of the v1.0 plan) inside a window
  that no longer has buffer.
- **Removes a risk instead of managing it.** Rebinding hardcoded
  workspace and lakehouse IDs across environments is unverified; not
  promoting means it never has to work.
- **Portfolio value is unchanged.** A reviewer sees one working
  environment with full history. The environment split demonstrated a
  practice, but not a capability the portfolio depends on.

### Alternatives considered

**Keep DEV→PROD as specified.** Demonstrates Deployment Pipelines, a
real enterprise practice. Rejected for the time cost and the unverified
ID-rebinding risk, both concentrated in the final week before expiry.

**Create PROD manually by rebuilding the items.** Rejected: duplicated
effort with no promotion mechanism to show.

### Consequences

- **Supersedes** Phase 2 §10, Phase 4 §2.3.2 and Phase 4 §12, and the
  `environment` and `data_scope` pipeline parameters of Phase 4 §7.6.
- The `-dev` suffix on the workspace name no longer implies a PROD
  counterpart. The README should say so.
- Deployment Pipelines are not demonstrated. In a client engagement
  they would be the default; this ADR is the answer when asked why.
- The capacity move (S8-1, S8-2) must complete before trial expiry.
  See the checkpoints in `phase5_dev_plan.md` §2.1.

## ADR-012 — Bronze notebooks on the Fabric Python runtime

**Date:** 2026-09-30
**Status:** Accepted

### Context

Fabric notebooks run on one of two runtimes. **PySpark** starts a Spark
session. **Python** runs a single-node container with pandas and no
Spark.

ADR-007 and Phase 2 specify the three Bronze notebooks as
"Notebook (Python)". `phase5_dev_plan.md` §3 (Sprint 5) describes them
as "PySpark in place of pandas". The two documents disagree.

The Bronze inputs are small: one REST API, four legacy XLS files, and
one XLSX. The local validation scripts (ADR-001) are pandas. A Spark
session takes the full FTL4 allocation (4 CU) for its whole lifetime
(ADR-007 addendum, 2026-08-26).

### Decision

The three Bronze notebooks (`spi_nb_bronze_energy`,
`spi_nb_bronze_construction`, `spi_nb_bronze_tax`) run on the **Python**
runtime. They use pandas, and they write Delta tables with the
`deltalake` library. The runtime for the Silver and Gold notebooks is
decided in Sprint 6.

### Rationale

- **Right-sized compute.** Spark is for distributed workloads. These
  inputs fit in memory by orders of magnitude.
- **No contention for the Spark ceiling.** The Bronze chain does not
  hold the 4 CU that a Spark session takes.
- **A near 1:1 port.** The only runtime change is the write: Parquet
  becomes Delta. The ADR-001 reconciliation becomes pandas against
  pandas, which is stricter than planned.
- **Consistent with ADR-007**, which already specified Python.

### Alternatives considered

**PySpark, as in the dev plan.** Rejected. It requires rewriting proven
pandas logic in a second API, and it pays the full session cost for no
benefit at this volume.

### Consequences

- Supersedes the "PySpark in place of pandas" wording in
  `phase5_dev_plan.md` §3 (Sprint 5).
- The High Concurrency question (whether notebooks share one Spark
  session) no longer applies to Bronze.
- **Unverified until the first run of `spi_nb_bronze_energy`:** the
  Delta write path from the Python runtime, and its CU consumption.
  Record both as an addendum.
- The availability of `xlrd` and `openpyxl` in the Python runtime is
  verified per notebook, at its first run.

### Addendum — 2026-10-01: verified at first run

The two points the Consequences left unverified until the first run of
`spi_nb_bronze_energy` are now resolved.

**Delta write path.** Delta write from the Python runtime works, but
not through the mounted path `/lakehouse/default/Tables/...`, which
fails because the mount does not support the rename a Delta commit
needs. It works through the OneLake `abfss://` URL with a bearer token
(see `lessons-learned.md`, Python notebooks).

**CU consumption.** Measured in the Capacity Metrics app (14-day item
view): `spi_nb_bronze_energy` consumed 1,410 CU-s over 996 s of
runtime, aggregated across all runs on 2026-09-30. That is ≈1.4 CU/s,
against 4.0 CU/s for a Spark session (ADR-007 addendum, 2026-08-26).
The figure includes interactive development runs and the forced-failure
run; per-run attribution was not isolated. The rate (CU per second of
runtime), not the total, is the comparable figure. Rationale confirmed.

**Libraries.** The REE notebook needed no extra libraries. `xlrd` and
`openpyxl` are still to be verified with the Construction and Tax
notebooks.

Decision unchanged.

### Addendum — 2026-10-01: xlrd

`xlrd` is not included in the Fabric Python runtime (`ModuleNotFoundError`).
It is installed with an inline `%pip install xlrd==2.0.1` in the first code
cell of `spi_nb_bronze_construction`. This works in both interactive and
pipeline runs (verified with `spi_pl_bronze_construction`). No Fabric
Environment is needed. `openpyxl` is still to be verified with the Tax
notebook.

CU measured in the Capacity Metrics app: `spi_nb_bronze_construction`
consumed 525 CU-s over 382 s of runtime (14-day item view, including the
failed first run and interactive runs). That is ≈1.4 CU/s, the same rate
as `spi_nb_bronze_energy`.

### Addendum — 2026-10-03: openpyxl

`openpyxl` is included in the Fabric Python runtime. `spi_nb_bronze_tax`
imported it at its first run with no `%pip install`.

All library checks listed in the Consequences are now closed: the REE
notebook needed no extra libraries, `xlrd` needs an inline `%pip`
(2026-10-01 addendum), and `openpyxl` needs nothing.

Decision unchanged.

## ADR-013 — Construction Bronze stores the raw XLS grid

**Date:** 2026-10-01
**Status:** Accepted

### Context

Phase 3 defines `spi_bronze_construction_raw` in long format: one row
per value, with `region_name`, `period_raw`, `indicator_category` and
`indicator_value_raw` already derived. That design puts the parsing of
the XLS layout (header rows, region blocks, period labels) inside the
Bronze notebook.

The local validation script `cons_bronze_load.py` (Sprint 2, ADR-001)
does not do this. It stores each sheet as received: every cell as a
string, in positional columns `col_01` … `col_NN`, plus lineage columns.

Inspection of the four source files shows that the layout is not
uniform:

| File | Rows | Columns | Grid offset |
|---|---|---|---|
| `01401400.XLS` | 243 | 12 | none |
| `01401600.XLS` | 244 | 14 | shifted one row down and one column right |
| `01402600.XLS` | 243 | 12 | none |
| `01402800.XLS` | 243 | 13 | none |

No file has merged cells (`merged_cells` is empty in all four).

### Decision

Bronze follows the local script. `spi_bronze_construction_raw` holds
the raw grid of all four files, appended into one table. Missing
positional columns are null. Parsing the layout into long format moves
to the Silver notebook (Sprint 6).

### Rationale

- **Bronze is data as received.** A layout parser is business logic.
  If MITMA changes the layout, a raw Bronze keeps loading, and only
  Silver needs fixing. The raw data is never lost.
- **The offset file proves the point.** `01401600.XLS` differs from the
  other three. Handling that is a transformation rule, and it belongs
  with the other transformation rules in Silver.
- **Consistent with ADR-001.** The local script is the Bronze
  implementation; its output is the reconciliation baseline.

### Alternatives considered

**Long format in Bronze, as in Phase 3.** Rejected. It mixes parsing
logic into ingestion, and a layout change would stop Bronze loading
entirely.

### Consequences

- Supersedes the Bronze column list of Phase 3 (Source 4) and the
  `parse_xls_sheet()` / `derive_metadata()` scope of Phase 4 §5.3.
- Sprint 6 Silver takes on the layout parsing: header rows, region
  blocks, period labels, the per-file offset, and subtotal rows.
- Phase 3's assumption of merged cells does not hold for the current
  files. No forward-fill is needed.

### Validation — 2026-10-01

| File | Rows (Fabric) | Rows (Sprint 2 baseline) | Columns |
|---|---|---|---|
| `01401400.XLS` | 247 | 243 | 12 |
| `01401600.XLS` | 248 | 244 | 14 |
| `01402600.XLS` | 247 | 243 | 12 |
| `01402800.XLS` | 247 | 243 | 13 |
| **Total** | **989** | **973** | |

Each file has exactly 4 more rows than the baseline, because MITMA has
published new data since Sprint 2. Column counts match. Missing positional
columns are real nulls, not the text `"nan"`, verified with `COUNT(col_13)`
and `COUNT(col_14)` per file. Pipeline log row: `success`, 989.

The year label is sparse, so Silver still needs a forward-fill for it. This
is unrelated to merged cells.

### Addendum — 2026-10-03: same approach for Tax

Phase 3 (Source 5) and Phase 4 §5.4 specify `spi_bronze_tax_raw` with
column names taken from the sheet's header row. The local validation
script `tax_bronze_load.py` does not do this: like Construction, it
stores positional columns `col_01` … `col_76`, and the header row is
kept as the first data row.

**Decision.** Tax follows the local script, as Construction does.

**Rationale.**

- **The header names are not valid column names as they are.** They
  contain spaces, dots, parentheses and accents (`D.E. Andalucía`,
  `Servicios Centrales (Participación CC.AA.)`). Delta tables without
  column mapping reject spaces and parentheses in column names. Using
  them would mean renaming them in Bronze, which is a transformation.
- **Nothing is lost.** The header row is stored as received, as the
  first row. Silver reads the column meanings from it.
- **One Bronze pattern for both spreadsheet sources.** Both store raw
  positional string columns plus lineage. Layout logic lives in Silver.

**Inspection of the source (local copy, 2026-10-03).**

| Item | Value |
|---|---|
| Workbook | 6 sheets, ~10.6 MB (Phase 3 estimated ~6 MB) |
| Sheet in scope | `datos_delegaciones` |
| Columns | 76: `Ejercicio`, `Mes`, `Concepto`, `Total`, then 72 offices |
| Data rows | 10,485 = 45 concepts × 233 months (2007-01 to 2026-05) |
| Trailing empty rows | 1,127 (the sheet's used range is larger than the data) |
| Total rows read | 11,613 (header + data + empty) |

**Consequences.**

- Supersedes "Column names from the sheet header row" in Phase 3
  (Source 5) and the `to_dataframe()` description in Phase 4 §5.4.
- Silver Tax takes on: promoting the header row, dropping the trailing
  empty rows, selecting the `Total`, `D.E. Madrid` and `D.E. Cataluña`
  columns, and the unpivot.
- Reconciliation rule for future loads: data rows = 45 × number of
  months. It stays valid as AEAT publishes new months.

### Validation — 2026-10-03 (Tax)

Fabric loaded 11,613 rows and 78 columns (76 positional plus 2 lineage)
into `spi_bronze_tax_raw`. A structural query returned:

| Item | Fabric (2026-10-03) | Local copy (2026-10-03 addendum) |
|---|---|---|
| Header rows | 1 | 1 |
| Months | 236 (2007-01 to 2026-08) | 233 (2007-01 to 2026-05) |
| Concepts | 45 | 45 |
| Data rows | 10,620 = 236 × 45 | 10,485 = 233 × 45 |
| Empty rows | 992 | 1,127 |
| **Total rows** | **11,613** | **11,613** |

AEAT has published three more months since the local copy. New months
fill the sheet's trailing empty rows, so the total row count stays the
same. The valid check for Tax is data rows = 45 × months, not the
total. Pipeline log row: `success`, 11613.

### Addendum — 2026-10-03: Schema changes

The Rationale above states that if MITMA changes the layout, "a raw
Bronze keeps loading". This needs refining. Two kinds of layout change
behave differently:

- **Same number of columns** (rows shifted, columns reordered, labels
  changed). Bronze absorbs it: every cell is a string in a positional
  column, so the write succeeds. Silver must catch it, because the
  positions no longer mean what Silver expects.
- **Different number of columns.** `write_deltalake(mode="overwrite")`
  fails. Overwrite refuses a schema change unless
  `schema_mode="overwrite"` is set, and the Bronze notebooks do not set
  it. This is the expected behaviour of the `deltalake` library; it has
  not yet been tested here.

This is intended. The load fails loudly instead of landing a different
shape. `schema_mode="overwrite"` is deliberately not set.

For Construction, the table width is that of the widest of the four
files (currently 14, from `01401600.XLS`). A change in a narrower file's
column count only changes how many columns are null; it does not change
the table schema and does not fail the load.
