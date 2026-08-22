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
Activated 2026-08-21, expires ~2026-10-20.

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