# Lessons Learned

Operational findings encountered while building SPI on Microsoft Fabric.
Platform behaviour discovered by building, not by reading documentation —
most of it is either undocumented, documented misleadingly, or scattered
across sources that never appear together.

Findings are recorded here. *Decisions* are recorded in
[`spi_adr_log.md`](spi_adr_log.md).

---

## Fabric Warehouse — T-SQL surface

- `PRIMARY KEY` is not accepted inside `CREATE TABLE`, even with
  `NOT ENFORCED`. Create the table first, then
  `ALTER TABLE ... ADD CONSTRAINT ... NOT ENFORCED`.
- `TIMESTAMP` is not a date/time type. It is a deprecated synonym for
  `ROWVERSION`, and only one is permitted per table. Use `DATETIME2(6)`;
  Fabric caps precision at 6 digits, not SQL Server's 7.
- `VARCHAR` without an explicit length silently becomes `VARCHAR(1)`.
  The DDL succeeds and data truncates without warning.
- `IDENTITY` is not supported. Surrogate keys are assigned in load logic.
- Constraints are never enforced. Uniqueness is entirely the
  responsibility of the load logic.
- The query editor red-underlines `ENFORCED`. Cosmetic; statements
  execute correctly.
- The Lakehouse SQL analytics endpoint is read-only. T-SQL cannot INSERT
  into Lakehouse Delta tables — this constrains where a pipeline-written
  log table can live.

---

## Capacity — FTL4 (4 CU)

- A Spark session consumes 4.0 CU/second for its entire lifetime,
  regardless of what it computes. Measured: 1,375.95 CU-s over 343.98 s
  of session lifetime for a notebook that printed one line.
- Two concurrent Spark sessions cannot coexist on 4 CU. Notebook
  execution must be sequential.
- The binding constraint is instantaneous concurrency, not daily volume.
  A full development day — DDL work, interactive queries, and a
  331,520-row pipeline run — consumed 1,893 CU-s against a daily budget
  of 345,600 (0.55%).
- The default Medium starter pool requests 16 Spark vCores; FTL4
  provides 8. Autoscale must be pinned to a single node or sessions are
  rejected outright.
- Session startup on the pre-warmed starter pool is ~5 seconds, not
  minutes. Custom environments cold-start and are considerably slower.

---

## Data Pipelines

- `$$FILENAME` resolves to an internal GUID when the source is HTTP
  rather than a file system. Use a static value or derive it from the
  URL.
- `activity()` matches on display name exactly. Rename activities before
  writing expressions that reference them; renaming afterwards breaks
  every reference with no warning until runtime.
- Parameter defaults must be literal values — `@pipeline().RunId` cannot
  be a default. Use an `empty()` fallback expression in the consuming
  activity instead.
- A child pipeline invoked from a parent receives its own `RunId`, not
  the parent's. Correlation across a run requires passing the parent's
  ID explicitly as a parameter.
- The Notebook activity timeout has a minimum of 10 minutes (format
  `D.HH:MM:SS`), so a short timeout cannot be used to force a failure.
- To test a failure path without changing code, pass a base parameter
  of the wrong type (e.g. a String where the notebook expects an int).
  The notebook fails in seconds, before any write.

---

## Dataflows Gen2

- A destination offers only **Append** or **Replace**. Replace truncates
  the **entire** destination table, not the rows the dataflow produced.
  With a fact table shared by several sources, Replace from one source
  erases all the others.
- Merge is greyed out until the dataflow holds a second query to merge
  with. Reference tables (dimensions) are added as queries of their own.
- Reference-only queries should have staging disabled and no data
  destination, or every refresh writes a staging copy of them.
- **Trim** removes leading and trailing whitespace only. Repeated
  internal spaces need an explicit replace step.
- Changing type to decimal fails on Spanish-locale values (`103,899`).
  Replace comma with period first, then change type.

---

## notebookutils — what it does not do

Runtime 1.3. Verified by introspection in a sandbox notebook, not from
documentation.

- `notebookutils.data` is data profiling — `convert_to_spark_df`,
  `profile`, `profile_for_data_wrangler`. No connection or query
  methods, and no `help()`.
- `notebookutils.warehouse` manages Warehouse *artifacts* — create, get,
  update, delete, list. It does not execute SQL against them.
- `notebookutils.connections` exposes `getCredential` only.

There is no notebookutils path for running arbitrary SQL against a
Fabric Warehouse from a notebook. Writing to a Warehouse from PySpark
requires the Spark connector (`synapsesql`), which stages the DataFrame
and issues COPY INTO.

---

## Python notebooks

- `write_deltalake` against the mounted path
  `/lakehouse/default/Tables/<table>` fails with
  `Unable to rename file — Operation not permitted (os error 1)`. The
  mounted path does not support the rename a Delta commit needs.
- Fix: write to the OneLake `abfss://` URL directly, with a bearer token
  from `notebookutils.credentials.getToken("storage")` and
  `use_fabric_endpoint` set:

  ```python
  table_uri = (
      "abfss://<workspace-id>@onelake.dfs.fabric.microsoft.com/"
      "<lakehouse-id>/Tables/<table>"
  )
  storage_options = {
      "bearer_token": notebookutils.credentials.getToken("storage"),
      "use_fabric_endpoint": "true",
  }
  write_deltalake(table_uri, df, mode="overwrite", storage_options=storage_options)
  ```
- `notebookutils.notebook.exit()` stops the notebook on purpose. In an
  interactive run, Fabric marks the exit cell with ✗ even though the exit
  succeeded (the output shows `ExitValue: …`). In a pipeline run, the
  Notebook activity reports Succeeded and passes the value to the next
  activity. The ✗ is expected and is not an error.
- `xlrd` is not in the Python runtime (`ModuleNotFoundError`). An inline
  `%pip install xlrd==2.0.1` in the notebook works, including in pipeline
  runs. No Fabric Environment is needed.
- `openpyxl` is included in the Python runtime (unlike `xlrd`). No
  `%pip install` is needed.
- Reading a Delta table that does not exist with `deltalake`
  (`DeltaTable(uri, …)`) fails with `TableNotFoundError` and the message
  `No files in log segment`. The message does not name the table; the
  URI in the notebook is the place to look.

---

## Authentication and connections

- Fabric's connection type for Azure SQL Database is **SQL Server** —
  there is no separate Azure SQL entry. Authentication method
  **OAuth 2.0** is what other Microsoft surfaces label "Organizational
  account".
- OAuth 2.0 stores a delegated *user* token, which expires. Pipeline
  failures with authentication errors weeks after a working setup are
  re-authentication, not misconfiguration. Production would use a
  service principal or workspace identity.
- Azure CLI refresh tokens expire after 90 days of inactivity
  (`AADSTS700082`). `DefaultAzureCredential` walks its entire credential
  chain before failing, so the output is long and the actual cause
  appears near the bottom. Fix: `az login --tenant <id>`.
- These two are the same phenomenon in different places: delegated user
  tokens expire, service principals and workspace identities do not. Any
  pipeline depending on user-delegated authentication will eventually
  fail this way.

**Two error codes that look alike and are not:**

| Code | Where | Cause | Fix |
|---|---|---|---|
| `AADSTS70008` | Fabric connection creation | Authorization code expired before exchange — transient | Retry |
| `AADSTS700082` | Azure CLI / `DefaultAzureCredential` | Refresh token expired after 90 days inactivity | `az login` |

---

## Tenant configuration

- GitHub Git integration requires a dedicated tenant setting — *"Users
  can sync workspace items with GitHub repositories"* — disabled by
  default and listed under **Integration settings**, separately from the
  general Git integration switches. Until it is enabled, the GitHub tile
  in workspace settings is greyed out with no explanation.
- The *"export items to Git repositories in other geographical
  locations"* switch is not enforced for GitHub and has no bearing on
  this.
- Searching tenant settings by keyword is more reliable than browsing by
  section.

---

## Azure SQL — free tier

- The Free General Purpose Serverless tier has a monthly vCore-second
  allowance with **overage billing disabled**. When the allowance is
  exhausted, the database becomes unavailable for the remainder of the
  billing period rather than incurring charges.
- Auto-pause after inactivity means the first connection triggers a
  resume and fails with error 40613. Connection timeouts must exceed
  60 seconds, and clients need retry logic.
- Fabric's connection test does not tolerate cold start well. Warm the
  database with a query before testing a new connection, or a timeout
  will look like a configuration fault.

---

## Source data

- The local validation files (Sprints 1–2) are older than the live
  sources. All three notebook sources had more periods in Fabric than
  locally. Reconcile local against Fabric by structure (columns, layout,
  row arithmetic), not by row counts (ADR-001, 2026-10-03 addendum).

### IPC (INE)

- Bronze row count 331,520 against the ~50,000 estimated in Phase 1 §3.
  Resolves to **12,390** rows in Gold after filtering to
  `tipo_de_dato = 'Índice'`: 3 regions × 14 ECOICOP groups × 295 months
  (2002-01 to 2026-07). An earlier estimate of ~37,000 was three times
  too high; 12,390 is measured.
- `total` uses comma as decimal separator (`103,899` = 103.899). Silver
  casting must replace comma with period before conversion.
- The current month is published with a NULL value. Silver logic must
  tolerate this rather than treating it as a failure.
- For a single region and `tipo_de_dato`, `periodo` alone does not
  identify a row — `grupos_ecoicop` does, at 14 rows per period. The
  natural key is `(region, ecoicop_group, periodo)`.
- A hand-typed dimension row contained a **double space**
  (`04  Vivienda, agua, electricidad, gas y otros combustibles`) while
  INE's label had one. It looks identical on screen, fails an
  exact-match join, and was only caught because the Gold lookup used a
  Left outer join (null key) rather than an inner join (silently dropped
  rows). Join-key values in seeded dimensions should be copied from the
  source data, never retyped.

### IPI (INE, via Azure SQL)

- The staging table is `dbo.staging_ipi_raw`, as created by
  `ipi_bronze_load.py`. Phase 4 §2.2.4 names it `stg_ipi_raw`.
- The loader wrote Bronze lineage columns (`_ingestion_timestamp`,
  `_source_file`) into the staging table. The Copy Activity's additional
  `_ingestion_timestamp` then collided with the source column: error
  9019, duplicate column names. Resolved with an explicit-column source
  query. A simulated transactional source should not carry Bronze
  metadata.
- The data-type column arrives as `Índice y tasas`, not `Tipo de dato`,
  and is stored in Bronze as `indice_y_tasas`. The two INE sources
  therefore differ in this column name; each Silver dataflow filters on
  its own.
- Bronze: 309,960 rows, matching the staging table. Gold: 8,379 rows.

### Encoding is not consistent across INE endpoints

- IPC (`csv_bdsc` endpoint): **ISO-8859-15**
- IPI (manual export): **UTF-8 with BOM** (`utf-8-sig`)

Verify encoding per file rather than assuming an institution-wide
convention.

### Energy (REE)

- The API returns the current month as a running total, not a complete
  month. Silver drops every period from the month of
  `_ingestion_timestamp` onwards (ADR-015, Decision 1).
- Madrid energy demand drops about 25× from **2026-02**: about 2.9M MWh
  in January 2026, about 107k MWh in the months after. Cause unknown,
  source side: the values come from REE as received, not from SPI code.
  Silver keeps them unchanged, and the report carries a note (ADR-015).

### Construction (MITMA)

- `-` means no value. Silver must convert it to null.
  - 2026-10-06: corrected. `-` means no tenders in the month, so it is
    0, not null (ADR-016).
- The year appears only on the first month row of each block. Silver
  must forward-fill it.
- `01401600.XLS` is offset by one row and one column relative to the
  other three files (ADR-013).
- The column header is an image. No cell names a region, so regions can
  only be mapped by position, checked against the image (ADR-016).
- MITMA revises past months between releases. Two downloads of the same
  file months apart differ on earlier values, e.g. the 2025 national
  total of table 8: 6,876,428 vs 6,875,278 thousand EUR.

### Tax (AEAT)

- The sheet `datos_delegaciones` has a fixed used range. New months
  replace trailing empty rows, so the total row count does not change
  until the trailing empty rows run out (~22 months at 45 rows per
  month). See ADR-013, 2026-10-03 validation.
- Blank cells arrive as `''`, not null. Construction also has real nulls
  (missing columns). Silver must treat both `''` and NULL as empty.
- Units (thousand EUR, `miles de euros`) appear only in the summary
  sheets (`cuadro_conceptos`, `cuadro_delegaciones`,
  `gráfico_evolución`), never on `datos_delegaciones`.
- `Total` = `Delegaciones` + `Servicios Centrales`, exactly. The two
  `Servicios Centrales (Participación CC.AA. / CC.LL.)` columns are
  outside `Total`: they are non-zero only in some net and refund rows,
  and adding them breaks the identity (ADR-017).
- `I.SOCIEDADES Ingresos brutos` does not equal its three sub-items in
  38 of 233 periods: an unbroken run 2013-07 to 2015-05 (up to 251,701
  thousand EUR nationally, in 2013-07) and scattered gaps of a few
  units in other years. Not usable as a guard.
- CAP.I and CAP.II contain taxes that are not listed as concepts. The
  listed taxes do not add up to their chapter; the grand total does
  equal CAP.I + CAP.II + CAP.III.
- Negative values are genuine: net values where a month's refunds
  exceed receipts, and at least one gross value (`CAP.III Ingresos
  brutos`, D.E. Madrid). A non-negative check would be wrong.
- No revisions found between two releases: a copy ending 2026-03 and
  one ending 2026-05 are identical on all 231 shared periods. Unlike
  MITMA (Construction).
