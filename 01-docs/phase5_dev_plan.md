# Phase 5 — Development Plan

> **Status:** Living document. Internal guide — not a formal deliverable.
> **Scope:** Phase 4.5 (closure) → Phase 5 (Fabric development) → Phase 6 (publication).
> **Owner:** Gastón Baloira
> **Last updated:** May 2026
> **Target completion:** ~10 weeks (range: 9–13 weeks depending on dedication)

---

## 1. Strategy and Working Contract

### 1.1 Pedagogical contract

This project is simultaneously a **portfolio deliverable** and a **learning vehicle**. The two goals are not in tension if the working dynamic is correct.

**Author writes the code. Claude teaches and reviews.** Specifically:

| Claude's role | Author's role |
|---|---|
| Concept primers before each new technical block (SQL↔PySpark mapping, idiomatic patterns, Fabric specifics) | Writes 100% of the productive code that lands in the repo |
| Notebook scaffolding (cell structure, function signatures, `# TODO` markers) | Completes TODOs, asks when blocked, never copy-pastes without understanding |
| Line-by-line reviews of submitted code | Before any commit: explains the code in own words, as if defending to a client |
| Guided debugging (questions, not solutions) | Tolerates productive discomfort early — speed comes after fluency |
| Walkthroughs of pre-existing code (e.g. `ipi_bronze_load.py`) | Owns every line. Can answer "why this and not that?" without notes |

**Exceptions where Claude may produce code directly:**
- Pure repetitive boilerplate (imports, headers, logging helper signatures already specified in Phase 4)
- T-SQL DDL for the Gold layer (author is SQL-senior; this is not where the learning curve lives)
- DAX measures (same rationale)
- Fabric configuration that is not code but settings (deployment rules, semantic model wiring)

**Definition of "owned" code:** the author can, without any reference material, explain in plain language to a non-technical interviewer what the code does, why each design choice was made, and what would change if a constraint changed (e.g. "what if the API returned 1M rows instead of 10K?").

### 1.2 Why phased learning, not pre-study

The author has 5+ years of SQL experience. PySpark's DataFrame API is essentially SQL expressed via method chaining. The "what" is already understood; the "how" (Python syntax, Fabric specifics) is best learned **applied to this exact problem**, not in abstract tutorials.

Phase 4.5 doubles as the Python ramp-up. Phase 5 sprints are ordered to introduce difficulty progressively: Dataflows (no Python) → Bronze notebooks (mostly classic Python) → Silver/Gold notebooks (PySpark).

### 1.3 Quality bar

Every artifact in the repo must pass the **client defense test**: if a freelance client opened a code review and asked "walk me through this and justify the decisions", the author can do it cold, in 5 minutes per artifact, without referring to documentation.

If at any point a notebook or pipeline cannot pass this test, the sprint does not close. Re-walkthrough first.

---

## 2. Timeline Overview

| Sprint | Block | Trial | Calendar duration | Effort (3–5h/day) |
|---|---|---|---|---|
| **0** | IPI walkthrough — author takes ownership of existing script | No | 3–4 days | ~12–16 h |
| **0.5** | Python primer — applied mini-course for the libraries used | No | 2–3 days | ~8–12 h |
| **1** | Phase 4.5 — Energy API local validation | No | 4–5 days | ~15–20 h |
| **2** | Phase 4.5 — Construction XLS + Tax XLSX local validation | No | 5–7 days | ~20–28 h |
| **3** | Fabric setup + PySpark primer + first toy notebook | **Trial Day 1** | 3–4 days | ~12–16 h |
| **4** | IPC + IPI end-to-end via Dataflows Gen2 | Active | 5–7 days | ~20–28 h |
| **5** | Bronze notebooks: Energy, Construction, Tax | Active | 7–10 days | ~28–40 h |
| **6** | Silver + Gold notebooks (PySpark heavy) | Active | 7–10 days | ~28–40 h |
| **7** | Master pipeline, semantic model, Power BI report | Active | 5–7 days | ~20–28 h |
| **8** | DEV→PROD deployment, screenshots, Loom, F2 PAYG migration | Active (closure) | 4–6 days | ~16–24 h |
| **9** | Phase 6 — GitHub publication, README, lessons learned | Optional | 5–7 days | ~20–28 h |
| | **Total** | | **50–70 days calendar** | **~200–280 h** |

**Trial budget check:** Sprints 3 → 8 = ~31–44 calendar days inside the trial. Comfortable margin against the 60-day window. Phase 6 happens after PROD migration to F2 PAYG (paused), so trial expiry is not a constraint.

**Buffer policy:** if any sprint takes 25% longer than estimated, that's normal — no recalibration needed. If it takes 50% longer, pause and reassess scope or working dynamic.

---

## 3. Sprint Breakdown

Each sprint below has: **goal**, **task list** (with IDs), **dependencies**, **definition of done**, and **risks**. Estimations assume the working contract above.

---

### Sprint 0 — IPI walkthrough (own the existing code)

**Goal.** Author takes full ownership of `ipi_bronze_load.py`. Can explain every block, justify every design decision, and identify what would change under different constraints.

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S0-1 | Read the script end-to-end alone, mark every line not understood | 1 | Annotated copy with ❓ markers |
| S0-2 | Block-by-block walkthrough session with Claude (author explains, Claude challenges) | 4–6 | Verbal mastery; ❓ markers cleared |
| S0-3 | Concept deep-dives surfaced during S0-2 (likely: Entra auth, ODBC, bulk insert mechanics, retry logic, encoding handling) | 3–5 | Margin notes / micro-cheatsheet in `lessons-learned.md` |
| S0-4 | Defense rehearsal: author explains the full script as if to a client, no notes | 1 | Ready for next sprint |

**Definition of Done.** Author can answer cold, without notes:
- Why Entra-only authentication and not SQL auth?
- Why bulk insert and not row-by-row?
- What encoding is used and why?
- What happens if the connection drops mid-load?
- What would change if the source CSV was 10x larger?

**Risk.** If S0-2 reveals deeper gaps than expected, expand S0-3. Do not skip to Sprint 0.5 with unresolved ❓.

---

### Sprint 0.5 — Python applied primer

**Goal.** Build minimum applied fluency in the exact libraries the project uses, before attacking new code.

**Scope (intentionally narrow).** Only what the project uses:
- `requests` — GET, headers, status codes, retries, timeouts
- `openpyxl` — reading XLSX, navigating sheets, cells, ranges
- `xlrd` — reading legacy XLS, merged cells handling
- File I/O, CSV handling with non-UTF-8 encodings
- Functions, type hints, docstrings, `try/except` patterns
- `logging` module basics

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S05-1 | Claude delivers cheatsheet: SQL→Python idiom mapping for common operations | 0 (Claude) | Markdown reference, lives in `lessons-learned.md` |
| S05-2 | Author completes 4–5 micro-exercises (each <30 lines, isolated): one per library | 4–6 | Working snippets, self-verified |
| S05-3 | Claude reviews the snippets, marks non-idiomatic patterns | 1 | Refined snippets |
| S05-4 | Author rewrites snippets applying the corrections, explains changes verbally | 2 | Internalized patterns |

**Definition of Done.** Author can write from scratch, without reference: a function that downloads a CSV from a URL, handles a non-200 response, logs the result, and returns a pandas DataFrame.

**Risk.** Scope creep — the temptation to "study Python more broadly". Resist. The project is the curriculum.

---

### Sprint 1 — Phase 4.5: Energy API local validation

**Goal.** Author writes a working local Python script that calls the REE API for the three geographic entities and the full year range, parses the JSON, and produces a flat DataFrame ready for Bronze ingestion. Saves it as Parquet locally for verification.

**Why locally first?** Per Phase 4.5 rationale: debug API quirks, pagination, JSON structure, encoding — all without burning trial hours. When this lands in Fabric (Sprint 5), the only new piece is the Delta write.

**Tasks.**

| ID | Task | Est. (h) | Dependencies | Output |
|---|---|---|---|---|
| S1-1 | Claude delivers concept primer: REE API specifics (JSONAPI, geo entities, response structure) | 0 | — | Mini-doc |
| S1-2 | Claude scaffolds the script: function signatures with TODOs per Phase 4 §5.2 | 0 | S1-1 | `energy_local_validation.py` skeleton |
| S1-3 | Author implements `build_request_url()` | 1 | S1-2 | Function + manual test |
| S1-4 | Author implements `fetch_with_retry()` (the meaty one — exponential backoff, retry-on-status-list, timeout) | 3–4 | S1-3 | Function with simulated failure tests |
| S1-5 | Author implements `parse_response()` (JSONAPI navigation: `included[] → attributes.values[]`) | 2–3 | S1-4 | Function + sample-payload test |
| S1-6 | Author implements `build_dataframe()` with explicit schema | 1–2 | S1-5 | Pandas DataFrame |
| S1-7 | Author implements `main()` — orchestrate the three geo entities × year loop | 1–2 | S1-6 | End-to-end run |
| S1-8 | Claude review pass — line by line | 1 | S1-7 | Review notes |
| S1-9 | Author refactors per review, explains diffs | 1–2 | S1-8 | Final script |
| S1-10 | Defense rehearsal: explain the full script, edge cases, retry policy | 1 | S1-9 | Sprint closed |

**Definition of Done.**
- Script runs end-to-end and produces a DataFrame with the expected schema and row count.
- Author can defend: retry policy choice, schema explicitness, why `requests.Session()` (or not), error handling at boundaries.
- Script committed to `/prerequisites/energy-api-validation/`.

**Risk.** API quirks (rate limiting, undocumented edge cases) may surface. Buffer is built into S1-4 estimate.

---

### Sprint 2 — Phase 4.5: Construction XLS + Tax XLSX local validation

**Goal.** Two local Python scripts, one per source. Construction is the harder one (legacy XLS, merged cells, multi-row headers, 4 files to consolidate). Tax is structurally simpler but the workbook is large (~6 MB) and the target sheet has a crosstab format requiring unpivot.

**Order rationale.** Construction first — if blockers appear, time pressure is lower. Tax is more procedural once the Construction patterns are internalized.

**Tasks — Construction (S2A).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S2A-1 | Claude primer: `xlrd` for legacy XLS, merged-cell semantics, multi-row header strategies | 0 | Mini-doc |
| S2A-2 | Author implements file download (4 URLs) | 1 | Files cached locally |
| S2A-3 | Author implements single-file parser (one XLS → DataFrame) | 4–6 | Function + test |
| S2A-4 | Author implements consolidation across the 4 files | 1–2 | Unified DataFrame |
| S2A-5 | Claude review + author refactor | 2 | Final script |
| S2A-6 | Defense rehearsal | 0.5 | Sprint half closed |

**Tasks — Tax (S2B).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S2B-1 | Claude primer: `openpyxl` patterns, sheet extraction by name, crosstab → tidy unpivot logic | 0 | Mini-doc |
| S2B-2 | Author implements XLSX download + sheet extraction (`datos_delegaciones`) | 2 | Raw DataFrame |
| S2B-3 | Author implements unpivot transformation (the conceptual challenge) | 3–4 | Tidy DataFrame |
| S2B-4 | Author implements delegation → 3 geographic entities mapping | 1–2 | Mapped DataFrame |
| S2B-5 | Claude review + author refactor | 2 | Final script |
| S2B-6 | Defense rehearsal | 0.5 | Sprint closed |

**Definition of Done.**
- Both scripts produce DataFrames consistent with Phase 3 source-to-target mappings.
- Outputs saved as Parquet for later comparison against Fabric Silver.
- Author can defend: why pandas here and not PySpark, why these specific column transformations, what happens if a new XLS file is added in the future.
- Phase 4.5 is **closed**. All 5 sources have validated transformation logic.

**Risk.** Construction merged cells are notoriously fragile. If S2A-3 explodes past 8h, escalate: pair-program a single block together, then author continues.

---

### Sprint 3 — Fabric setup + PySpark primer + toy notebook

**Goal.** Trial activated. DEV workspace operational. Author has written one trivial PySpark notebook end-to-end, just to validate the environment and internalize the Fabric notebook UX.

**Trial activation criteria (must all be true before activating):**
- [ ] Phase 4.5 fully closed (all 5 sources validated locally)
- [ ] Sprint 3 setup tasks (workspace, lakehouse, warehouse, DDL) are pre-planned and ready to execute in 1–2 sessions
- [ ] Author has at least 2 weeks of clear runway ahead

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S3-1 | Activate Fabric Trial in personal tenant | 0.5 | Trial active, capacity assigned |
| S3-2 | Create `spi-spain-indicators-dev` workspace, assign capacity | 0.5 | Workspace ready |
| S3-3 | Create `spi_lakehouse` and `spi_warehouse` items | 0.5 | Items ready |
| S3-4 | Execute Gold DDL from Phase 4 §4 (Claude provides — author SQL-senior) | 1 | Empty fact + 5 dimensions in Warehouse |
| S3-5 | Create `spi_log_pipeline_execution` table per Phase 4 §10 | 0.5 | Logging table ready |
| S3-6 | Create the logging helper module (Claude scaffolds, author reviews and adopts) | 1 | Helper ready for reuse |
| S3-7 | Configure Azure SQL connection (cross-tenant) per Phase 4 §8 | 1–2 | Connection tested |
| S3-8 | Claude primer: PySpark DataFrame API, SQL↔PySpark side-by-side, Delta read/write in Fabric, Lakehouse paths | 0 | Mini-doc, lives in `lessons-learned.md` |
| S3-9 | Author writes a toy notebook: read a Lakehouse Delta table, do `.filter().groupBy().count()`, write back. Pure throwaway. | 3–5 | Confidence + Fabric UX familiarity |
| S3-10 | Defense rehearsal: author explains the toy notebook | 0.5 | Sprint closed |

**Definition of Done.**
- DEV workspace fully provisioned per Phase 4 §2.
- Author has executed at least one PySpark notebook in Fabric and understood the run mechanics (sessions, attached lakehouse, default lakehouse, kernel restart, error display).
- Trial countdown active and tracked.

**Risk.** Cross-tenant Azure SQL connection (Phase 4 §9 documents this is non-trivial). Allocate buffer; if S3-7 explodes, do not block other sprints — IPI ingestion can be deferred to mid-Sprint 4.

---

### Sprint 4 — IPC + IPI end-to-end via Dataflows Gen2

**Goal.** Two of the five sources live in production: Bronze → Silver → Gold, fully orchestrated. Quick wins build momentum and validate the medallion pattern end-to-end before tackling notebook complexity.

**Why these two first?** Per Phase 2 component matrix: lowest complexity, no Python required. Pure Fabric UX practice.

**Tasks.**

| ID | Task | Est. (h) | Source | Output |
|---|---|---|---|---|
| S4-1 | Build pipeline `spi_pl_bronze_ipc` (Copy Activity from INE URL → `spi_bronze_ipc_raw`) | 2–3 | IPC | Bronze table populated |
| S4-2 | Build Dataflow Gen2 `spi_df_silver_ipc` (Bronze → Silver per Phase 4 §6) | 3–4 | IPC | Silver table populated |
| S4-3 | Build Dataflow Gen2 `spi_df_gold_ipc` (Silver → Gold fact mapping) | 2–3 | IPC | Rows in `spi_fact_indicators` |
| S4-4 | Build pipeline `spi_pl_bronze_ipi` (Copy Activity from Azure SQL → `spi_bronze_ipi_raw`) | 2–3 | IPI | Bronze table populated |
| S4-5 | Build Dataflow Gen2 `spi_df_silver_ipi` | 3–4 | IPI | Silver table populated |
| S4-6 | Build Dataflow Gen2 `spi_df_gold_ipi` | 2–3 | IPI | More rows in `spi_fact_indicators` |
| S4-7 | Wire logging into both pipelines (start/success/failure) | 1–2 | Both | Log rows visible |
| S4-8 | Validation queries: row counts, sample rows, type checks | 1 | Both | Validation pass |
| S4-9 | Defense rehearsal: explain choice of Dataflow vs. Notebook for these sources | 0.5 | — | Sprint closed |

**Definition of Done.**
- IPC and IPI fully landed in `spi_fact_indicators` with logging evidence.
- Author can defend: when to use Dataflow Gen2 vs. PySpark notebook, what each Power Query step does, schema enforcement strategy.

**Risk.** Dataflow Gen2 has UI quirks (refresh delays, intermittent errors). Save often. Document any issue in `lessons-learned.md` — these are portfolio gold.

---

### Sprint 5 — Bronze notebooks (Energy, Construction, Tax)

**Goal.** Three Bronze notebooks in Fabric, ingesting the API and the two Excel sources. The local Python from Phase 4.5 is the foundation — the new piece is Delta write + Fabric runtime adaptation.

**Tasks per notebook (template, applies to S5-Energy, S5-Construction, S5-Tax).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| Sx-1 | Create notebook `spi_nb_bronze_<source>`, attach Lakehouse | 0.5 | Notebook scaffold |
| Sx-2 | Port functions from local script (author rewrites, does not copy-paste) | 3–6 | Functions in notebook |
| Sx-3 | Adapt I/O: replace `pd.to_parquet` with PySpark Delta write to Lakehouse | 1–2 | Delta write working |
| Sx-4 | Add metadata columns: `_ingestion_timestamp`, `_source_file` | 0.5 | Schema complete |
| Sx-5 | Wrap `main` in try/except, integrate logging helpers | 1 | Logging integrated |
| Sx-6 | Parameterize for pipeline injection (Phase 4 §3.2) | 0.5 | Parameters cell tagged |
| Sx-7 | Test run end-to-end | 1 | Bronze table populated |
| Sx-8 | Claude review + author refactor | 1–2 | Final notebook |
| Sx-9 | Defense rehearsal | 0.5 | Notebook closed |

**Why "rewrite, not copy-paste" in Sx-2.** This is non-negotiable. Re-typing the code from the local script forces re-engagement with every line. Catches the "I read it but didn't really understand it" failure mode. Yes, it takes longer. That's the point.

**Estimated effort per notebook:** ~9–14 h. Three notebooks → ~28–40 h total.

**Definition of Done (sprint level).**
- Three Bronze tables populated in Lakehouse with logging evidence.
- Author can defend any of the three notebooks cold.
- Local Python scripts in `/prerequisites/` and Fabric notebooks in `/src/notebooks/bronze/` are diff-reviewable: differences are deliberate (Delta write, parameterization), not accidental.

**Risk.** Energy is the lightest learning curve (mostly classic Python). Construction is the heaviest (xlrd in Spark runtime — verify library availability early; if missing, install via Fabric Environment per Phase 4 §3.7).

---

### Sprint 6 — Silver + Gold notebooks (PySpark heavy)

**Goal.** Three Silver notebooks + one Gold notebook. **This is where PySpark gets serious.** Until now Python was mostly classic; now it's DataFrame transformations on Delta tables.

**Why this comes after Sprint 5.** By now the author has 3 Bronze notebooks under the belt and Fabric UX is fluent. The cognitive load of "learning PySpark" can be isolated from "learning Fabric".

**Tasks per Silver notebook (template).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| Sx-1 | Claude primer: PySpark patterns for this specific transformation (e.g. unpivot, deduplication, type casting) | 0 | Mini-doc |
| Sx-2 | Author scaffolds the notebook structure (header, imports, params, functions, main) | 1 | Skeleton |
| Sx-3 | Author writes the read from Bronze Delta | 0.5 | Source DataFrame |
| Sx-4 | Author writes the transformation functions per Phase 3 source-to-target mapping | 4–7 | Transformation functions |
| Sx-5 | Author writes the Silver Delta write | 0.5 | Silver table populated |
| Sx-6 | Logging + parameterization | 1 | Production-ready |
| Sx-7 | Claude review + author refactor | 2 | Final notebook |
| Sx-8 | Defense rehearsal | 0.5 | Notebook closed |

**Estimated per Silver notebook:** ~9–13 h. Three notebooks → ~27–39 h.

**Tasks — Gold notebook (`spi_nb_gold_load`).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S6-G1 | Claude primer: writing to Warehouse from a notebook (Spark connector, MERGE patterns) | 0 | Mini-doc |
| S6-G2 | Author implements dimension loads (5 dimensions, all with similar pattern — write the first with full review, the rest faster) | 4–6 | Dimensions populated |
| S6-G3 | Author implements fact load with surrogate key resolution (joins to dimensions to get keys) | 3–5 | Fact populated for sources 3, 4, 5 |
| S6-G4 | Reconciliation queries — total fact rows match expected per source | 1 | Reconciliation pass |
| S6-G5 | Claude review + author refactor | 2 | Final notebook |
| S6-G6 | Defense rehearsal — full Gold story including IPC/IPI from Dataflows | 1 | Sprint closed |

**Definition of Done (sprint level).**
- All 5 dimensions populated. Fact populated from all 5 sources.
- Author can defend: surrogate key strategy, MERGE vs. truncate-and-load decision, why notebook for Gold and not Dataflow.
- Star schema is queryable end-to-end via T-SQL in Warehouse.

**Risk.** This is the densest sprint. If Sprint 6 stretches significantly, do not compress Sprint 7 — extend the calendar. Quality of Silver/Gold logic is what reviewers will judge most harshly.

---

### Sprint 7 — Master pipeline + Power BI

**Goal.** End-to-end orchestration with one click, plus the consumption layer.

**Tasks — Orchestration (S7A).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S7A-1 | Build `spi_pl_bronze` master (orchestrates all 5 Bronze: 2 pipelines + 3 notebooks) | 2–3 | Bronze layer one-click |
| S7A-2 | Build `spi_pl_silver` master (orchestrates 2 Dataflows + 3 notebooks) | 2–3 | Silver layer one-click |
| S7A-3 | Build `spi_pl_gold` master (orchestrates 2 Dataflows + Gold notebook) | 1–2 | Gold layer one-click |
| S7A-4 | Build `spi_pl_master` (Bronze → Silver → Gold sequential) | 1–2 | Full pipeline one-click |
| S7A-5 | End-to-end run, verify all logging entries are clean | 1 | Production-ready |

**Tasks — Power BI (S7B).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S7B-1 | Create Direct Lake semantic model on `spi_warehouse` | 1 | Model item |
| S7B-2 | Configure relationships, mark date table per Phase 4 §11 | 1–2 | Model wired |
| S7B-3 | Author writes DAX measures (claude provides catalog, author types and tests) | 3–5 | Measures live |
| S7B-4 | Build the 6-page report per Phase 3 specification | 4–6 | Report complete |
| S7B-5 | Save as PBIP, ready for repo | 0.5 | PBIP exported |
| S7B-6 | Defense rehearsal — full report walkthrough as if to a stakeholder | 1 | Sprint closed |

**Definition of Done.**
- `spi_pl_master` runs end-to-end without manual intervention. All 5 sources land in Gold.
- Power BI report renders all 6 pages. Author can present it as a stakeholder-facing demo.

**Risk.** Direct Lake has specific gotchas with refresh and column types. Phase 4 §11 anticipates them — re-read before starting S7B-1.

---

### Sprint 8 — DEV→PROD + portfolio capture

**Goal.** PROD workspace operational, portfolio assets captured, F2 PAYG migration complete.

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S8-1 | Create `spi-spain-indicators-prod` workspace | 0.5 | PROD ready |
| S8-2 | Configure Fabric Deployment Pipeline: DEV → PROD bind | 1 | Pipeline ready |
| S8-3 | Configure deployment rules per Phase 4 §12.3 | 1 | Rules configured |
| S8-4 | Trigger deployment, verify all artifacts copied | 1 | PROD provisioned |
| S8-5 | Run `spi_pl_master` in PROD with `data_scope = full_history` | 2–3 | Full data in PROD |
| S8-6 | Capture curated screenshots (8–15 per Phase 0 §7): workspace, lakehouse, warehouse, notebooks, pipelines, dataflows, semantic model, report pages | 2–3 | `/docs/screenshots/` populated |
| S8-7 | Record Loom demo — full E2E walkthrough, ~10–15 min | 2–3 | Loom URL ready for README |
| S8-8 | Migrate PROD to F2 PAYG (paused by default) — **before trial day 53** | 1 | Permanent portfolio surface |
| S8-9 | Final smoke test in PROD on F2 PAYG | 1 | Sprint closed |

**Definition of Done.**
- PROD running on F2 PAYG (paused).
- Screenshots, Loom video, and code all captured.
- Trial can expire safely without losing the portfolio.

**Risk.** **Trial day 53 is a hard deadline.** Sprint 8 must close before then. If running behind by Sprint 7, deprioritize polish (e.g. extra report pages) to make this date.

---

### Sprint 9 — Phase 6: GitHub publication

**Goal.** Repository is portfolio-grade. README is the landing page that converts a recruiter visit into a callback.

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S9-1 | Export all Fabric artifacts (notebooks .ipynb, pipelines JSON, dataflows, PBIP) into `/src/` | 2–3 | Code in repo |
| S9-2 | Author writes folder-level READMEs (`/src/notebooks/`, `/src/pipelines/`, etc.) | 2–3 | Navigable structure |
| S9-3 | Consolidate `lessons-learned.md` from all the mini-notes accumulated through sprints | 2 | Polished doc |
| S9-4 | Author writes the **main README** (project landing) — the highest-leverage artifact in the entire repo | 4–6 | Hero document |
| S9-5 | Embed Loom + insert screenshots into README | 1 | Visual story |
| S9-6 | Final cross-check: every PDF in `/docs/`, every code file referenced, no broken links | 1 | Quality pass |
| S9-7 | Final defense rehearsal: 30-minute mock interview with Claude on the full project | 2 | Production-ready |

**Definition of Done.**
- Repository is shareable as the answer to "show me your work" without any verbal preamble.
- README answers within 60 seconds of reading: what, why, how, what's the result, who built it.
- Author can hold a 30-minute technical conversation about any part of the project without notes.

**Risk.** README quality is the single highest-leverage piece. Do not rush S9-4. If short on time, cut S9-3 first.

---

## 4. Cross-Sprint Practices

### 4.1 Daily

- Start session: `git pull`, review the open task, re-read the Definition of Done for the current sprint.
- End session: commit with a meaningful message, push, update the sprint task status (✅ / 🚧 / ❌).

### 4.2 Weekly

- Friday: 30-min retrospective. What worked, what didn't, what's the risk for next week. Append to `lessons-learned.md`.
- If a sprint slipped, do not "catch up" by skipping defense rehearsals. The rehearsal is the deliverable.

### 4.3 Per artifact

- Every notebook, pipeline, and dataflow has a markdown header with: purpose, inputs, outputs, dependencies, last-updated.
- Every commit message follows: `[sprint-id] short description` (e.g. `[S5-Energy] implement fetch_with_retry`).

### 4.4 The defense rehearsal — what it actually looks like

At the end of each task that produces a notebook, pipeline, or dataflow:

1. Author closes the IDE and the documentation.
2. Claude asks 3–5 probing questions about the artifact, mixing easy and hard:
   - Easy: "what does this notebook do?"
   - Medium: "why did you choose `withColumn` over `select`?"
   - Hard: "what would change if the source had 100x the rows?"
   - Hard: "what's the failure mode if the Lakehouse loses connection mid-write?"
3. If the author hesitates or hand-waves, the rehearsal fails. Re-read the code, re-rehearse.

This ritual is the single most important quality gate in the whole plan. **It is what converts "completed code" into "owned code".**

---

## 5. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Cross-tenant Azure SQL connection fails in Fabric | Medium | High (blocks IPI in Sprint 4) | Phase 4 §9 documents the resolution. Allocate buffer in Sprint 3. If still blocked, defer IPI to Sprint 5 — non-fatal. |
| `xlrd` not available in Fabric Spark runtime | Medium | Medium (blocks Construction notebook) | Verify in Sprint 3 toy notebook. If missing, install via Fabric Environment (Phase 4 §3.7). |
| Trial expires before Sprint 8 closes | Low (with this plan) | Critical | Sprint 8 must close before trial day 53. F2 PAYG migration is the irreversible safety net. |
| Author productivity dips for 2+ weeks (life) | Medium | Medium | Plan has built-in buffer. Honest re-estimation is fine; compressing scope is fine. Compromising the working contract (Claude writing code instead of teaching) is not fine. |
| Power BI report scope creeps | Medium | Low | Phase 3 specifies 6 pages. Build 6 pages. Iterate on polish post-publication, not pre. |
| Defense rehearsals start getting skipped under time pressure | High | Critical | If skipped, the portfolio loses its differentiator. Rehearsal ≠ optional. |
| Perfectionism on README delays Sprint 9 closure | Medium | Low | Time-box README at 6h max. v1 ships. Polish in v2 after publication. |

---

## 6. Definition of Project Done

The project is complete when **all** of the following are true:

- [ ] `spi-spain-indicators` GitHub repository is public and well-organized per Phase 0 §9.
- [ ] All 5 Fabric components (Lakehouse, Pipelines, Notebooks, Dataflows Gen2, Warehouse, Power BI) are present and used appropriately.
- [ ] All 5 sources land in `spi_fact_indicators` end-to-end with a single pipeline trigger.
- [ ] PROD environment runs on F2 PAYG (paused), available to demonstrate live.
- [ ] README answers the 5 core questions (what / why / how / result / who) within 60 seconds of reading.
- [ ] Loom demo (10–15 min) is embedded in README.
- [ ] 8–15 curated screenshots in `/docs/screenshots/`.
- [ ] `lessons-learned.md` is a polished living document, not a dump of notes.
- [ ] Author can defend any single artifact in the repo cold, in under 5 minutes, in front of a technical interviewer.
- [ ] Author has executed at least one full mock-interview rehearsal of 30+ minutes.

When all 10 are checked: the project is ready to be the centerpiece of the freelance portfolio.

---

## 7. What success looks like in 6 months

A freelance prospect asks: "show me end-to-end Fabric work you've built". The author sends one URL. Within five minutes the prospect has:

- Read the README and understood the business problem and solution.
- Watched the Loom and seen the working pipeline.
- Browsed two notebooks and seen idiomatic, commented PySpark.
- Seen the Power BI report.

The next message from the prospect is: "*Can we get on a call?*"

That is what this plan is designed to produce.

---

## 8. Changelog

| Version | Date | Notes |
|---|---|---|
| 0.1 | May 2026 | Initial plan. Drafted before Sprint 0 kickoff. Living document — sprint outcomes update sections 3, 4, 5 in place; estimates may be revised mid-flight with explicit notes. |
