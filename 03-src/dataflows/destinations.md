# Dataflow destinations

The `.pq` exports hold the M code only. Data destinations, update methods,
column mappings and staging are set in the dataflow UI and are not exported.
This file records them for the rebuild (`01-docs/rebuild_checklist.md` §10).

What the repository or the ADRs already state is filled in, with its source.
Destination, table and update method were read off the trial workspace on
2026-10-19 (hover summary of each query's **Data destination**). Schema
options for the Warehouse destinations and staging were **not captured**
before the trial expired: on rebuild, use automatic mapping and disable
staging on the reference queries, then record what Fabric shows.

**Workspace field.** Some destinations point to *Current workspace*
(`spi_df_gold_ipc`, `spi_df_gold_dimensions` region/calendar), others to the
workspace by name (`spi_df_silver_*`, `spi_df_gold_ipi`,
`spi_df_gold_dimensions` indicator). On rebuild, set every destination to
*Current workspace* so it does not point at the old workspace.

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
| `spi_bronze_ipc_raw` | `spi_lakehouse` · `dbo.spi_silver_ipc_cleaned` | Replace | Auto mapping, schema change allowed | not captured |

**Column mapping.** Output of the M query, in order:

| Column | M type |
|---|---|
| `region_name` | text |
| `indicator_category` | text |
| `year` | Int64 |
| `month` | Int64 |
| `indicator_value` | number |
| `domain` | text |

Open (not captured before expiry): the Delta column types the destination creates (`number` →
double or decimal?), and whether any column is renamed or excluded in the
mapping.

---

## `spi_df_silver_ipi`

| Query | Destination | Update method | Schema options | Staging |
|---|---|---|---|---|
| `spi_bronze_ipi_raw` | `spi_lakehouse` · `dbo.spi_silver_ipi_cleaned` | Replace | Auto mapping, schema change allowed | not captured |

**Column mapping.** Same six columns and types as `spi_df_silver_ipc`. Rows
with a null `indicator_value` are filtered out in M (`Filtered rows 1`).

Open: as for IPC.

---

## `spi_df_gold_ipc`

| Query | Destination | Update method | Schema options | Staging |
|---|---|---|---|---|
| `spi_silver_ipc_cleaned` (fact) | `spi_warehouse` · `dbo.spi_fact_indicators` · existing table | **Append** | not captured | not captured |
| `spi_dim_indicator` (reference) | None | — | — | not captured |
| `spi_dim_region` (reference) | None | — | — | not captured |

Never Replace: Replace truncates the whole shared fact table (ADR-010).
`spi_pl_gold` runs `DELETE … WHERE source_key = 1` before this dataflow
(ADR-018, addendum 2026-10-15).

Reference queries have no destination. `lessons-learned.md` (Dataflows Gen2)
says they should have staging disabled; set it that way on rebuild.

**Column mapping.** Fact query output → `dbo.spi_fact_indicators`:

| Column | M type | Warehouse type |
|---|---|---|
| `indicator_key` | Int64 | `INT` |
| `region_key` | Int64 (no explicit type step) | `INT` |
| `calendar_key` | Int64 | `INT` |
| `source_key` | Int64 (constant 1) | `INT` |
| `indicator_value` | number | `DECIMAL(18,4)` |

Open: confirm on rebuild that the mapping is by name with no column excluded.

**Reference query M** is exported to
`spi_df_gold_ipc__spi_dim_indicator.pq` and `spi_df_gold_ipc__spi_dim_region.pq`
(2026-10-19). Both are plain Warehouse navigations; replace the workspace and
Warehouse IDs on rebuild.

---

## `spi_df_gold_ipi`

| Query | Destination | Update method | Schema options | Staging |
|---|---|---|---|---|
| `spi_silver_ipi_cleaned` (fact) | `spi_warehouse` · `dbo.spi_fact_indicators` · existing table | **Append** | not captured | not captured |
| `spi_dim_indicator` (reference) | None | — | — | not captured |
| `spi_dim_region` (reference) | None | — | — | not captured |

Same as `spi_df_gold_ipc`, with `source_key` = 2 and the DELETE on
`source_key = 2`. Reference-query M: `spi_df_gold_ipi__spi_dim_indicator.pq`
and `spi_df_gold_ipi__spi_dim_region.pq`.

---

## `spi_df_gold_dimensions`

| Query | Destination | Update method | Schema options | Staging |
|---|---|---|---|---|
| `spi_dim_region` | `spi_warehouse` · `dbo.spi_dim_region` · existing table | Replace | not captured | not captured |
| `spi_dim_calendar` | `spi_warehouse` · `dbo.spi_dim_calendar` · existing table | Replace | not captured | not captured |
| `spi_dim_indicator` | `spi_warehouse` · `dbo.spi_dim_indicator` · existing table | Replace | not captured | not captured |

Update methods confirmed in Fabric on 2026-10-19: Replace for all three.
`spi_dim_source` is not in this dataflow: it is seeded by the `INSERT`s in
`spi_gold_ddl.sql` (ADR-010, correction to Decision 2).

`spi_dim_region` is seeded twice: by the DDL `INSERT` and by this dataflow.
The dataflow owns the table; the DDL `INSERT` is the initial seed only
(ADR-010 addendum 2026-10-06).

Open, check on the first rebuild refresh: whether Replace into an existing Warehouse table keeps the DDL
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

Open: confirm on rebuild that each mapping is by name with no column excluded.
