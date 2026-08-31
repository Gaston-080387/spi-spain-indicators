# Lessons Learned

Personal log of conceptual breakthroughs, design decisions, and gotchas encountered while building the Spain Indicators Fabric project. Written narratively rather than as cheatsheet — the goal is to capture *why* and *what changed in my thinking*, not *how to use library X*.

---

## Sprint 0 — IPI Bronze Walkthrough

*(May 2026)*

Coming from a SQL background, I initially approached Python error handling with a fairly simple mental model: if something fails, catch it with try/except and move on. That worked well enough for small scripts, but while building this project I ran into a concept that completely changed how I think about debugging and reliability: raise.
The concept really clicked while reading the retry block of the IPI loader, where preserving the original exception context was essential to understand why a retry was happening in the first place.
The turning point was understanding the difference between using a bare raise versus raising a new exception like TypeError("Failure"). At first, both looked almost identical to me because they stop execution and surface an error. But in practice, they communicate very different things. A bare raise preserves the original traceback and context, while creating a new exception can overwrite the execution history that actually explains the failure.
That distinction changed the way I structure exception handling in Python. Instead of only thinking about “handling errors,” I started thinking about preserving observability and making failures easier to investigate.
For analytics and data engineering workflows, that distinction becomes especially important. Good error handling is not just about preventing crashes — it is about making future debugging faster, clearer, and far less painful.

---

## Sprint 0.5 — Python Applied Primer

*(June 2026)*

The Bronze=all-string pattern wasn't new to me; I had implemented it in SQL Server/SSIS as 'varchar stage tables' to eliminate casting errors. Recognizing that the medallion architecture formalizes that same instinct was a direct bridge between my on-premises experience and the modern cloud stack.

---

## Sprint 1 — Energy API Validation

*(June 2026)*

From the `build_request_url` function, I learned three things:
- The importance of thoroughly reading the API documentation to avoid future errors in the call.
- How important it is to define which elements are constants and which are parameters, depending on what varies for each region. Variables are defined within the function.
- When creating a list of tuples, adding a region is simply adding a row; neither the URL construction logic nor the fetch logic is touched, because the region is passed as a parameter and `main` iterates through the collection.

Regarding the `fetch_with_retry` function, I drew the following conclusions:
- When receiving a failure, one must ask:
- How do I find out? (status)
- Should I retry or not? (timeout, attempts)
- A bare `raise` block can only survive within an `except` block. Outside of that, there's nothing to retry, and it would result in a confusing error. - Attempts != retries. Waits are between attempts: always one less than GETs.

From the `parse_response` function, I've gained these insights:
- When a required field is not in the source, it must be injected as a parameter.
- It's important to distinguish between structure and data: Structures cannot fail and are enclosed in square brackets (] so they will be flagged if an error occurs. Data is left as silent failures, following the Bronze Layer principle.
- Order between loops: define the external structure first, then the internal structure.

I've drawn three conclusions from the `build_dataframe` function:
- Inferring types is not losing data. Casting is done for stability (not out of fear). Bronze Layer principle = mirroring.
- It's one thing to end everything as a string and another to see the specific string I want: That's why I kept the `isoformat` in the `timestamp` field even though I later cast the entire data frame to a string.
- In pandas, before writing a "for" loop over columns, I look for the vectorized version (astype).

During the consolidation of the 'main' function, as the orchestrator of the entire script, I encountered a snag worth mentioning: a design change based on actual testing of the script calling the API. I had to implement a new loop that took years because the API wouldn't let me call the entire previously defined range.

---

## Sprint 2 — Construction (MiTMA)

*(June 2026)*

From this script, I learned the following:
- Reinforcing the importance of good scaffolding: Functions, DocStrings, TODOs. You've done half the work; then it's just a matter of knowing Python code.
- Always consider which development layer you're working at: Bronze, Silver, or Gold. Having this clear influences development and prevents future inconsistencies.
Validate function by function; don't wait until the end of development.
- Create small intermediate functions when the opportunity arises (e.g., create a special function to cast cells to strings when they have multiple data types in the same column).

---

## Sprint 3 — Fabric setup

GitHub Git integration requires a dedicated tenant setting ("Users can sync workspace items with GitHub repositories"), disabled by default and listed separately from the general Git integration switches. Searching tenant settings by keyword is more reliable than browsing by section.

---

## Fabric Warehouse — T-SQL surface

- `PRIMARY KEY` is not accepted inside `CREATE TABLE`, even with
  `NOT ENFORCED`. Create the table first, then
  `ALTER TABLE ... ADD CONSTRAINT ... NOT ENFORCED`.
- `TIMESTAMP` is not a date/time type. It is a deprecated synonym for
  `ROWVERSION`, and only one is permitted per table. Use
  `DATETIME2(6)`; Fabric caps precision at 6 digits, not SQL Server's 7.
- `VARCHAR` without an explicit length silently becomes `VARCHAR(1)`.
  The DDL succeeds and data truncates without warning.
- `IDENTITY` is not supported. Surrogate keys are assigned in load
  logic.
- Constraints are never enforced. Uniqueness is entirely the
  responsibility of the load logic.
- The query editor red-underlines `ENFORCED`. Cosmetic; statements
  execute correctly.

## Data Pipelines

- `$$FILENAME` resolves to an internal GUID when the source is HTTP
  rather than a file system. Use a static value or derive from the URL.
- `activity()` matches on display name exactly. Rename activities
  before writing expressions that reference them; renaming afterwards
  breaks every reference with no warning until runtime.
- Parameter defaults must be literal values. Use `empty()` fallback
  expressions for dynamic defaults.

## Source data — IPC

- Bronze row count 331,520 against the ~50,000 estimated in Phase 1
  §3. Resolves to ~37,000 rows in Gold after filtering to
  `tipo_de_dato = 'Indice'` and three regions across ~20 years. Gold
  volume estimates in Phase 3 remain valid; the Bronze estimate does
  not.
- `total` uses comma as decimal separator (`103,899` = 103.899).
  Silver casting must replace comma with period before conversion.
- The current month is published with a NULL value. Silver logic must
  tolerate this rather than treating it as a failure.

## Pipeline activity naming convention

`cp_` Copy · `nb_` Notebook · `scr_` Script · `lkp_` Lookup ·
`if_` If Condition · `fail_` Fail

Single-source Bronze pipelines are named `spi_pl_bronze_<source>`.
The unsuffixed `spi_pl_bronze` is reserved for the master
orchestration pipeline (Sprint 7, S7A-1).

## S3-7 — Azure SQL connection findings

- The sprint plan describes this as a cross-tenant connection. It isn't.
  Both identities live in gastonbaloiraoutlook.onmicrosoft.com
  (Phase 4 §8.1). The task is same-tenant and correspondingly simpler.
- The Fabric identity is already the Entra admin of spi-sqlserver-gb,
  so the GRANT in Phase 4 §8.3 was unnecessary. Deviation from the
  least-privilege model is documented.
- Two Entra identities exist in this project. The portal account
  (gaston.baloira@outlook.com) owns the subscription but has no database
  access; the work account owns Fabric and administers SQL. The Query
  editor uses the portal session identity and therefore cannot query
  this database.
- Fabric connection type is "SQL Server" — there is no separate Azure SQL
  Database entry. Authentication method "OAuth 2.0" is what other
  surfaces label "Organizational account".
- OAuth 2.0 stores a delegated user token that expires. Pipeline
  failures with authentication errors weeks later are re-authentication,
  not misconfiguration. Production would use a service principal or
  workspace identity.
- AADSTS70008 on connection creation is a transient authorization-code
  expiry, not a permissions problem. Retrying resolves it.