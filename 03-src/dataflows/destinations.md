# Dataflow destinations

The `.pq` exports hold the M code only. Data destinations, update methods,
column mappings and staging are set in the dataflow UI and are not exported.
This file records them for the rebuild (`01-docs/rebuild_checklist.md` §10).

What the repository or the ADRs already state is filled in, with its source.
`[TO CHECK]` marks what has to be read off the Fabric UI (each query's
destination settings: **Data destination** → gear icon).

Fields per query:

- **Destination**: item and table. *Existing table* means the table is created
  first by `03-src/warehouse/spi_gold_ddl.sql` and the dataflow writes into it.
- **Update method**: Append or Replace (the only two, `lessons-learned.md`,
  Dataflows Gen2).
- **Schema options**: whether *Use automatic settings* is on, and for Replace
  whether the schema is dynamic or fixed.
- **Column mapping**: output columns and their M types; how they map to the
  destination columns.
- **Staging**: whether *Enable staging* is on for the query.

---

## `spi_df_silver_ipc`

| Query | Destination | Update method | Schema options | Staging |
|---|---|---|---|---|
| `[TO CHECK: query name]` | `spi_lakehouse` · `spi_silver_ipc_cleaned` · `[TO CHECK: new or existing table]` | Replace (`.pq` header; `03-src/dataflows/README.md`) | `[TO CHECK]` | `[TO CHECK]` |

**Column mapping.** Output of the M query, in order:

| Column | M type |
|---|---|
| `region_name` | text |
| `indicator_category` | text |
| `year` | Int64 |
| `month` | Int64 |
| `indicator_value` | number |
| `domain` | text |

`[TO CHECK]`: the Delta column types the destination creates (`number` →
double or decimal?), and whether any column is renamed or excluded in the
mapping.

---

## `spi_df_silver_ipi`

| Query | Destination | Update method | Schema options | Staging |
|---|---|---|---|---|
| `[TO CHECK: query name]` | `spi_lakehouse` · `spi_silver_ipi_cleaned` · `[TO CHECK: new or existing table]` | Replace (`.pq` header; `03-src/dataflows/README.md`) | `[TO CHECK]` | `[TO CHECK]` |

**Column mapping.** Same six columns and types as `spi_df_silver_ipc`. Rows
with a null `indicator_value` are filtered out in M (`Filtered rows 1`).

`[TO CHECK]`: as for IPC.

---

## `spi_df_gold_ipc`

| Query | Destination | Update method | Schema options | Staging |
|---|---|---|---|---|
| `[TO CHECK: query name]` (fact) | `spi_warehouse` · `dbo.spi_fact_indicators` · existing table | **Append** (ADR-010; `.pq` header) | `[TO CHECK]` | `[TO CHECK]` |
| `spi_dim_indicator` (reference) | None | — | — | Disabled? `[TO CHECK]` |
| `spi_dim_region` (reference) | None | — | — | Disabled? `[TO CHECK]` |

Never Replace: Replace truncates the whole shared fact table (ADR-010).
`spi_pl_gold` runs `DELETE … WHERE source_key = 1` before this dataflow
(ADR-018, addendum 2026-10-15).

Reference queries have no destination. `lessons-learned.md` (Dataflows Gen2)
says they should have staging disabled; whether they do here is
`[TO CHECK]`.

**Column mapping.** Fact query output → `dbo.spi_fact_indicators`:

| Column | M type | Warehouse type |
|---|---|---|
| `indicator_key` | Int64 | `INT` |
| `region_key` | Int64 (no explicit type step) | `INT` |
| `calendar_key` | Int64 | `INT` |
| `source_key` | Int64 (constant 1) | `INT` |
| `indicator_value` | number | `DECIMAL(18,4)` |

`[TO CHECK]`: that the mapping is by name with no column excluded.

**Reference query M is not in the repository.** The `.pq` header says the two
reference queries "read from spi_warehouse; not reproduced here". They have to
be rebuilt by hand (Warehouse navigation to `dbo.spi_dim_indicator` and
`dbo.spi_dim_region`), or their M exported. `[TO CHECK: export their M]`

---

## `spi_df_gold_ipi`

| Query | Destination | Update method | Schema options | Staging |
|---|---|---|---|---|
| `[TO CHECK: query name]` (fact) | `spi_warehouse` · `dbo.spi_fact_indicators` · existing table | **Append** (ADR-010; `.pq` header) | `[TO CHECK]` | `[TO CHECK]` |
| `spi_dim_indicator` (reference) | None | — | — | Disabled? `[TO CHECK]` |
| `spi_dim_region` (reference) | None | — | — | Disabled? `[TO CHECK]` |

Same as `spi_df_gold_ipc`, with `source_key` = 2 and the DELETE on
`source_key = 2`. The reference-query M is not in the repository either.

---

## `spi_df_gold_dimensions`

| Query | Destination | Update method | Schema options | Staging |
|---|---|---|---|---|
| `spi_dim_region` | `spi_warehouse` · `dbo.spi_dim_region` · existing table | Replace (`.pq` header; ADR-010 addendum 2026-10-06) | `[TO CHECK]` | `[TO CHECK]` |
| `spi_dim_calendar` | `spi_warehouse` · `dbo.spi_dim_calendar` · existing table | Replace (`.pq` header) | `[TO CHECK]` | `[TO CHECK]` |
| `spi_dim_indicator` | `spi_warehouse` · `dbo.spi_dim_indicator` · existing table | Replace (`.pq` header) | `[TO CHECK]` | `[TO CHECK]` |

The rebuild checklist (§10) asks to confirm these update methods in Fabric
before the move; the `.pq` header says Replace for all three.
`spi_dim_source` is not in this dataflow: it is seeded by the `INSERT`s in
`spi_gold_ddl.sql` (ADR-010, correction to Decision 2).

`spi_dim_region` is seeded twice: by the DDL `INSERT` and by this dataflow.
The dataflow owns the table; the DDL `INSERT` is the initial seed only
(ADR-010 addendum 2026-10-06).

`[TO CHECK]`: whether Replace into an existing Warehouse table keeps the DDL
definition (`VARCHAR` lengths, `NOT NULL`, the `NOT ENFORCED` primary keys) or
drops and recreates the table with types inferred from M. This decides whether
the DDL or the dataflow defines these three tables after the first refresh.

**Column mapping.**

`spi_dim_region`:

| Column | M type | Warehouse type |
|---|---|---|
| `region_key` | Int64 | `INT` |
| `region_code` | text | `VARCHAR(3)` |
| `region_name` | text | `VARCHAR(50)` |
| `region_type` | text | `VARCHAR(50)` |

`spi_dim_calendar`:

| Column | M type | Warehouse type |
|---|---|---|
| `calendar_key` | Int64 | `INT` |
| `year` | Int64 | `INT` |
| `month` | Int64 | `INT` |
| `month_name` | text | `VARCHAR(20)` |
| `quarter` | Int64 | `INT` |
| `year_month` | text | `VARCHAR(7)` |
| `is_current_year` | logical | `BIT` |

`spi_dim_indicator`:

| Column | M type | Warehouse type |
|---|---|---|
| `indicator_key` | Int64 | `INT` |
| `indicator_name` | text | `VARCHAR(200)` |
| `indicator_category` | text | `VARCHAR(200)` |
| `domain` | text | `VARCHAR(100)` |
| `unit_of_measure` | text | `VARCHAR(100)` |
| `frequency` | text | `VARCHAR(50)` |

`[TO CHECK]`: that each mapping is by name with no column excluded.
