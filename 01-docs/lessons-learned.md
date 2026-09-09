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

## notebookutils — what it does not do

Runtime 1.3. Verified by introspection in a sandbox notebook, not from
documentation.

- `notebookutils.data` is data profiling — `convert_to_spark_df`, `profile`,
  `profile_for_data_wrangler`. No connection or query methods, and no
  `help()`.
- `notebookutils.warehouse` manages Warehouse artifacts — create, get,
  update, delete, list. It does not execute SQL against them.
- `notebookutils.connections` exposes `getCredential` only.

There is no `notebookutils` path for running arbitrary SQL against a Fabric
Warehouse from a notebook. Writing to a Warehouse from PySpark requires the
Spark connector (`synapsesql`), which stages the DataFrame and issues
`COPY INTO`.

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

### IPC (INE)

- Bronze row count 331,520 against the ~50,000 estimated in Phase 1 §3.
  Resolves to ~37,000 rows in Gold after filtering to
  `tipo_de_dato = 'Índice'` and three regions across ~24 years. Gold
  volume estimates in Phase 3 remain valid; the Bronze estimate does not.
- `total` uses comma as decimal separator (`103,899` = 103.899). Silver
  casting must replace comma with period before conversion.
- The current month is published with a NULL value. Silver logic must
  tolerate this rather than treating it as a failure.
- For a single region and `tipo_de_dato`, `periodo` alone does not
  identify a row — `grupos_ecoicop` does, at 14 rows per period. The
  natural key is `(region, ecoicop_group, periodo)`.

### Encoding is not consistent across INE endpoints

- IPC (`csv_bdsc` endpoint): **ISO-8859-15**
- IPI (manual export): **UTF-8 with BOM** (`utf-8-sig`)

Verify encoding per file rather than assuming an institution-wide
convention.
