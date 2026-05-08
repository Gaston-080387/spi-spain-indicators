# Phase 5 — Development Plan

> **Document Type:** Living development plan. Internal working artifact.
> **Scope:** Phase 4.5 (closure) → Phase 5 (Fabric development) → Phase 6 (publication).
> **Target Duration:** 10 weeks (range: 9–13 weeks depending on dedication).
> **Last Updated:** May 2026
> **Version:** 1.0

---

## 1. Strategy

### 1.1 Guiding principles

The development plan defined in this document is governed by three principles. Each addresses a specific class of risk identified during the design phases.

**Local validation precedes cloud execution.** Every Python-based source is prototyped locally against real production data before being implemented in Fabric. The output of local validation — a Parquet snapshot containing the expected transformation result — serves as the reconciliation baseline for the corresponding Silver table. This separation isolates three classes of problem (source-format quirks, transformation logic, Fabric runtime integration) that are otherwise tangled and disproportionately expensive to debug together.

**Sprints introduce one new technical dimension at a time.** The development sequence is ordered so that Dataflow Gen2 sources are completed before notebook sources, Bronze layer before Silver, and the master pipeline and semantic model are constructed only after the star schema is fully populated. This sequencing minimizes the surface area of "what could be wrong right now" at each stage and surfaces integration issues against a known-good substrate.

**Sprint closure is gated by output, not by task completion.** Each sprint defines its Definition of Done in concrete terms: rows landed in the fact table, logging entries written, row counts reconciled against baseline. A code review pass is mandatory per artifact and must clear before the sprint is considered complete.

### 1.2 Tooling

Development uses AI-assisted code review (Claude) for static analysis, idiomatic refinement, scaffolding, and architecture validation. AI assistance is treated as a peer reviewer integrated into the workflow — accelerating iteration on naming, structure, and edge case coverage without substituting design ownership. This reflects current Analytics Engineering practice in 2026: AI tooling is a standard component of the development stack, not a deviation from it.

### 1.3 Quality bar

Every artifact in the repository must pass the **client defense test**: a freelance client conducting a code review can request a walkthrough of any notebook, pipeline, or dataflow and receive a coherent, decision-justified explanation in under five minutes. Where an artifact cannot meet this standard, the corresponding sprint does not close until rework is complete.

---

## 2. Timeline Overview

| Sprint | Block | Trial Status | Calendar Duration | Effort (3–5 h/day) |
|---|---|---|---|---|
| **0** | IPI walkthrough — assimilation of existing reference script | Inactive | 3–4 days | ~12–16 h |
| **0.5** | Python applied primer — targeted fluency in project libraries | Inactive | 2–3 days | ~8–12 h |
| **1** | Phase 4.5 — Energy API local validation | Inactive | 4–5 days | ~15–20 h |
| **2** | Phase 4.5 — Construction XLS and Tax XLSX local validation | Inactive | 5–7 days | ~20–28 h |
| **3** | Fabric environment provisioning and PySpark primer | **Trial Day 1** | 3–4 days | ~12–16 h |
| **4** | IPC and IPI sources end-to-end via Dataflows Gen2 | Active | 5–7 days | ~20–28 h |
| **5** | Bronze notebooks (Energy, Construction, Tax) | Active | 7–10 days | ~28–40 h |
| **6** | Silver and Gold notebooks | Active | 7–10 days | ~28–40 h |
| **7** | Master pipeline orchestration and Power BI report | Active | 5–7 days | ~20–28 h |
| **8** | DEV→PROD deployment, portfolio capture, F2 PAYG migration | Active (closure) | 4–6 days | ~16–24 h |
| **9** | Phase 6 — GitHub publication and final polish | Optional | 5–7 days | ~20–28 h |
| | **Total** | | **50–70 days calendar** | **~200–280 h** |

**Trial budget validation.** Sprints 3 through 8 occupy approximately 31–44 calendar days within the 60-day trial window, providing comfortable margin against the deadline. Phase 6 publication occurs after the PROD environment has been migrated to F2 PAYG (paused state), removing trial expiry as a risk to portfolio availability.

**Buffer policy.** Sprint slippage of up to 25% is anticipated and requires no recalibration. Slippage exceeding 50% triggers a scope or sequencing review before continuing.

---

## 3. Sprint Specifications

Each sprint specification below contains: objective, task list with effort estimates, dependencies, definition of done, and identified risks. Estimates assume the working dynamic established in Section 1.

---

### Sprint 0 — IPI walkthrough

**Objective.** Full assimilation of the existing `ipi_bronze_load.py` reference script, validated through structured walkthrough. The author can explain every block, justify every design decision, and identify the impact of changing constraints (data volume, connection failure modes, encoding variants).

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S0-1 | Independent read of the script with annotation of unclear sections | 1 | Annotated copy with open questions |
| S0-2 | Block-by-block walkthrough session — verbal explanation under structured questioning | 4–6 | Verbal mastery; open questions resolved |
| S0-3 | Concept deep-dives on resolved gaps (likely candidates: Entra authentication, ODBC driver behavior, bulk insert mechanics, retry logic, encoding handling) | 3–5 | Notes integrated into `lessons-learned.md` |
| S0-4 | Defense rehearsal — full script explanation without reference material | 1 | Sprint closed |

**Definition of Done.** The author can answer cold the following questions: rationale for Entra-only authentication, choice of bulk insert pattern, encoding selection, behavior under mid-load connection failure, and impact on the loader of a 10× source-data volume increase.

**Risk.** Where Sprint S0-2 surfaces deeper conceptual gaps than anticipated, S0-3 expands proportionally. Sprint 0.5 does not begin while open questions remain.

---

### Sprint 0.5 — Python applied primer

**Objective.** Targeted fluency in the exact Python libraries used by the project. Scope is intentionally narrow: only what is required for Phase 4.5 and Phase 5 development.

**Scope.**

- `requests` — HTTP GET, headers, status codes, retry patterns, timeouts
- `openpyxl` — XLSX reading, sheet navigation, cell and range access
- `xlrd` — Legacy XLS reading, merged-cell handling
- File I/O with non-UTF-8 encodings; CSV handling
- Functions, type hints, docstrings, exception patterns
- The `logging` standard library module

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S05-1 | Cheatsheet delivered: SQL → Python idiom mapping for common operations | 0 | Reference document in `lessons-learned.md` |
| S05-2 | Four to five micro-exercises completed (each under 30 lines, isolated by library) | 4–6 | Working snippets, self-verified |
| S05-3 | Code review pass on submitted snippets — non-idiomatic patterns flagged | 1 | Review notes |
| S05-4 | Refactor pass with verbal justification of each correction | 2 | Internalized patterns |

**Definition of Done.** The author can write from scratch, without reference, a function that downloads a CSV from a remote URL, handles non-200 HTTP responses, logs the result, and returns a pandas DataFrame.

**Risk.** Scope creep into general Python study reduces sprint velocity without portfolio benefit. The project itself defines the curriculum boundary.

---

### Sprint 1 — Phase 4.5: Energy API local validation

**Objective.** A working local Python script that calls the REE API for the three geographic entities across the full year range, parses the JSONAPI response, and produces a flat DataFrame conforming to the Bronze contract. The script saves a Parquet snapshot for use as the Silver-layer reconciliation baseline.

**Rationale for local-first execution.** Per Phase 4.5 design: API quirks, pagination behavior, JSON structure ambiguities, and encoding edge cases are debugged outside the Fabric runtime. When the equivalent logic lands in the Sprint 5 Bronze notebook, the only new dimension introduced is the Delta write — every other element is already proven.

**Tasks.**

| ID | Task | Est. (h) | Dependencies | Output |
|---|---|---|---|---|
| S1-1 | Concept primer: REE API specifics (JSONAPI structure, geographic entities, response shape) | 0 | — | Reference document |
| S1-2 | Notebook scaffolding: function signatures with TODO markers per Phase 4 §5.2 | 0 | S1-1 | `energy_local_validation.py` skeleton |
| S1-3 | Implementation of `build_request_url()` | 1 | S1-2 | Function with manual test |
| S1-4 | Implementation of `fetch_with_retry()` — exponential backoff, retry-on-status-list, configurable timeout | 3–4 | S1-3 | Function with simulated-failure tests |
| S1-5 | Implementation of `parse_response()` — JSONAPI navigation through `included[] → attributes.values[]` | 2–3 | S1-4 | Function with sample-payload test |
| S1-6 | Implementation of `build_dataframe()` with explicit schema | 1–2 | S1-5 | Pandas DataFrame |
| S1-7 | Implementation of `main()` — orchestration of three geographic entities across the year range | 1–2 | S1-6 | End-to-end execution |
| S1-8 | Code review pass — line-by-line | 1 | S1-7 | Review notes |
| S1-9 | Refactor pass with explanation of each diff | 1–2 | S1-8 | Final script |
| S1-10 | Defense rehearsal: full script walkthrough including retry policy and edge cases | 1 | S1-9 | Sprint closed |

**Definition of Done.** Script executes end-to-end and produces a DataFrame conforming to the Bronze schema with the expected row count. Author can defend retry policy choice, schema explicitness, error handling at I/O boundaries, and `requests.Session()` usage decision. Script committed to `/prerequisites/energy-api-validation/`.

**Risk.** Undocumented API behavior (rate limiting, intermittent edge cases) may surface during S1-4. Estimate buffer is incorporated.

---

### Sprint 2 — Phase 4.5: Construction XLS and Tax XLSX local validation

**Objective.** Two local Python scripts, one per source. Construction (legacy XLS, merged cells, multi-row headers, four-file consolidation) is implemented first; Tax (multi-sheet XLSX requiring crosstab unpivot) follows.

**Sequencing rationale.** Construction presents the higher-risk parsing challenge. Implementing it first ensures any blockers surface while time pressure is lowest. Tax is more procedural once Construction patterns are internalized.

**Tasks — Construction (S2A).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S2A-1 | Concept primer: `xlrd` for legacy XLS, merged-cell semantics, multi-row header strategies | 0 | Reference document |
| S2A-2 | File download implementation (4 source URLs) | 1 | Files cached locally |
| S2A-3 | Single-file parser implementation (one XLS → DataFrame) | 4–6 | Function with test |
| S2A-4 | Cross-file consolidation logic | 1–2 | Unified DataFrame |
| S2A-5 | Code review pass and refactor | 2 | Final script |
| S2A-6 | Defense rehearsal | 0.5 | Sprint half closed |

**Tasks — Tax (S2B).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S2B-1 | Concept primer: `openpyxl` patterns, sheet extraction by name, crosstab-to-tidy unpivot strategy | 0 | Reference document |
| S2B-2 | XLSX download and target sheet (`datos_delegaciones`) extraction | 2 | Raw DataFrame |
| S2B-3 | Unpivot transformation implementation | 3–4 | Tidy DataFrame |
| S2B-4 | Delegation-to-geographic-entity mapping | 1–2 | Mapped DataFrame |
| S2B-5 | Code review pass and refactor | 2 | Final script |
| S2B-6 | Defense rehearsal | 0.5 | Sprint closed |

**Definition of Done.** Both scripts produce DataFrames conforming to the Phase 3 source-to-target mappings. Outputs are persisted as Parquet for Silver-layer reconciliation. Author can defend: choice of pandas over PySpark for local validation, specific column transformations applied, behavior under introduction of an additional source file. Phase 4.5 closes upon completion: all five sources have validated transformation logic.

**Risk.** Construction's merged-cell handling is structurally fragile. If S2A-3 exceeds 8 hours, escalation protocol applies: a single block is pair-implemented before the author resumes independently.

---

### Sprint 3 — Fabric environment provisioning and PySpark primer

**Objective.** Fabric Trial activated, DEV workspace fully operational per Phase 4 §2, and one trivial PySpark notebook executed end-to-end to validate the runtime and internalize the Fabric notebook user experience.

**Trial activation gate.** All of the following must be satisfied before the trial is activated:
- Phase 4.5 fully closed (all five sources validated locally).
- Sprint 3 setup tasks pre-planned and executable in 1–2 sessions.
- Minimum two-week clear runway available for continuous development.

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S3-1 | Activate Fabric Trial; assign capacity | 0.5 | Trial active |
| S3-2 | Create `spi-spain-indicators-dev` workspace; bind capacity | 0.5 | Workspace provisioned |
| S3-3 | Create `spi_lakehouse` and `spi_warehouse` items | 0.5 | Items provisioned |
| S3-4 | Execute Gold layer DDL per Phase 4 §4 | 1 | Empty fact and dimensions in Warehouse |
| S3-5 | Create `spi_log_pipeline_execution` table per Phase 4 §10 | 0.5 | Logging table provisioned |
| S3-6 | Implement logging helper module per Phase 4 §10 specification | 1 | Helper available for reuse |
| S3-7 | Configure cross-tenant Azure SQL connection per Phase 4 §8 | 1–2 | Connection tested |
| S3-8 | Concept primer: PySpark DataFrame API, SQL ↔ PySpark side-by-side mapping, Delta read/write in Fabric, Lakehouse path semantics | 0 | Reference document in `lessons-learned.md` |
| S3-9 | Toy notebook implementation: read a Lakehouse Delta table, execute `.filter().groupBy().count()`, write result back. Disposable artifact. | 3–5 | Runtime validation; UX familiarity |
| S3-10 | Defense rehearsal: toy notebook walkthrough | 0.5 | Sprint closed |

**Definition of Done.** DEV workspace fully provisioned per Phase 4 §2. Author has executed at least one PySpark notebook in Fabric and understands run mechanics: Spark session lifecycle, default Lakehouse attachment, kernel restart implications, error reporting surface. Trial countdown active and tracked.

**Risk.** Cross-tenant Azure SQL connection has documented complexity per Phase 4 §9. Buffer is allocated; if S3-7 blocks, the IPI ingestion path can be deferred to mid-Sprint 4 without impacting other workstreams.

---

### Sprint 4 — IPC and IPI end-to-end via Dataflows Gen2

**Objective.** Two of the five sources operational end-to-end: Bronze → Silver → Gold, fully orchestrated. These quick wins build operational momentum and validate the medallion pattern against the live environment before the higher-complexity notebook sources are tackled.

**Sequencing rationale.** Per Phase 2 component matrix, IPC and IPI present the lowest implementation complexity (no Python required) and provide pure Fabric UX practice. Validating the end-to-end pattern with these sources first reduces risk on the more complex notebook implementations that follow.

**Tasks.**

| ID | Task | Est. (h) | Source | Output |
|---|---|---|---|---|
| S4-1 | Build pipeline `spi_pl_bronze_ipc` (Copy Activity from INE URL → `spi_bronze_ipc_raw`) | 2–3 | IPC | Bronze table populated |
| S4-2 | Build Dataflow Gen2 `spi_df_silver_ipc` per Phase 4 §6 | 3–4 | IPC | Silver table populated |
| S4-3 | Build Dataflow Gen2 `spi_df_gold_ipc` (Silver → Gold fact mapping) | 2–3 | IPC | Rows in `spi_fact_indicators` |
| S4-4 | Build pipeline `spi_pl_bronze_ipi` (Copy Activity from Azure SQL → `spi_bronze_ipi_raw`) | 2–3 | IPI | Bronze table populated |
| S4-5 | Build Dataflow Gen2 `spi_df_silver_ipi` | 3–4 | IPI | Silver table populated |
| S4-6 | Build Dataflow Gen2 `spi_df_gold_ipi` | 2–3 | IPI | Additional rows in `spi_fact_indicators` |
| S4-7 | Integrate logging in both pipelines (start, success, failure events) | 1–2 | Both | Log entries verified |
| S4-8 | Validation queries: row counts, sample inspection, type verification | 1 | Both | Validation pass |
| S4-9 | Defense rehearsal: justification of Dataflow Gen2 versus notebook for these sources | 0.5 | — | Sprint closed |

**Definition of Done.** IPC and IPI fully resolved into `spi_fact_indicators` with logging evidence. Author can defend the architectural choice between Dataflow Gen2 and PySpark notebook, the function of each Power Query step, and the schema enforcement strategy applied.

**Risk.** Dataflow Gen2 has documented UI quirks (refresh delays, intermittent errors). Frequent saves are mandatory. Issues encountered are recorded in `lessons-learned.md` — these have direct portfolio value as concrete operational findings.

---

### Sprint 5 — Bronze notebooks (Energy, Construction, Tax)

**Objective.** Three Bronze notebooks operating in Fabric, ingesting the REE API and the two Excel sources into the Lakehouse. The local validation scripts authored during Phase 4.5 serve as the reference implementation. The notebooks adapt that proven logic to the Fabric runtime: PySpark in place of pandas, Delta writes in place of Parquet, parameterized for orchestration by the master pipeline.

**Tasks per source (template, applies to S5-Energy, S5-Construction, S5-Tax).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| Sx-1 | Create notebook `spi_nb_bronze_<source>`, attach Lakehouse, configure parameters cell | 0.5 | Notebook scaffold |
| Sx-2 | Port and adapt extraction logic from the local validation script | 3–6 | Functions in notebook |
| Sx-3 | Replace pandas/Parquet I/O with PySpark/Delta writes targeting `spi_lakehouse` | 1–2 | Delta write operational |
| Sx-4 | Inject metadata columns (`_ingestion_timestamp`, `_source_file`) per data contract | 0.5 | Schema complete |
| Sx-5 | Wrap entry point with structured exception handling and logging integration | 1 | Logging integrated |
| Sx-6 | Parameterize for pipeline injection per Phase 4 §3.2 | 0.5 | Parameters cell tagged |
| Sx-7 | End-to-end execution and reconciliation against the local Parquet baseline | 1 | Bronze table populated |
| Sx-8 | Code review pass and refactor | 1–2 | Final notebook |
| Sx-9 | Defense rehearsal | 0.5 | Notebook closed |

**Implementation note — re-implementation rather than import.** The local validation scripts and the Fabric notebooks share lineage but target different runtimes (pandas + filesystem versus PySpark + Delta). Treating each as an independent codebase, with the local script serving as a reference rather than a dependency, avoids cross-runtime portability constraints in either direction and keeps each implementation idiomatic to its environment.

**Estimated effort per notebook.** Approximately 9–14 h. Three notebooks total: ~28–40 h.

**Definition of Done.**
- Three Bronze tables populated in `spi_lakehouse` with row counts matching the local Parquet baseline.
- Logging entries captured in `spi_log_pipeline_execution` for all three notebook executions.
- Local Python scripts in `/prerequisites/` and Fabric notebooks in `/src/notebooks/bronze/` are diff-comparable: differences are deliberate (Delta write, parameterization) rather than incidental.

**Risk.** `xlrd` library availability in the Fabric Spark runtime requires verification early in the sprint. Where the library is unavailable, installation via Fabric Environment per Phase 4 §3.7 is the resolution path.

---

### Sprint 6 — Silver and Gold notebooks

**Objective.** Three Silver notebooks (Energy, Construction, Tax) and one Gold notebook (`spi_nb_gold_load`) operational. This sprint contains the densest concentration of PySpark transformation logic in the project: until this point, Python usage is largely classical (extraction, parsing, I/O); Silver and Gold introduce DataFrame transformation patterns at scale.

**Sequencing rationale.** By the entry point of Sprint 6, three Bronze notebooks have been completed and Fabric UX is fluent. Isolating the introduction of PySpark-intensive transformations from Fabric onboarding reduces cognitive load and improves debugging efficiency.

**Tasks per Silver notebook (template).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| Sx-1 | Concept primer: PySpark patterns specific to this transformation (unpivot, deduplication, type casting, etc.) | 0 | Reference document |
| Sx-2 | Notebook scaffold (header, imports, parameters, function signatures, main entry point) | 1 | Skeleton |
| Sx-3 | Read implementation from Bronze Delta source | 0.5 | Source DataFrame |
| Sx-4 | Transformation function implementations per Phase 3 source-to-target mappings | 4–7 | Transformation functions |
| Sx-5 | Silver Delta write implementation | 0.5 | Silver table populated |
| Sx-6 | Logging integration and parameterization | 1 | Production-ready notebook |
| Sx-7 | Code review pass and refactor | 2 | Final notebook |
| Sx-8 | Defense rehearsal | 0.5 | Notebook closed |

**Estimated effort per Silver notebook.** Approximately 9–13 h. Three notebooks total: ~27–39 h.

**Tasks — Gold notebook (`spi_nb_gold_load`).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S6-G1 | Concept primer: Warehouse writes from notebook (Spark connector behavior, MERGE patterns) | 0 | Reference document |
| S6-G2 | Dimension load implementations (5 dimensions, shared pattern — first dimension reviewed in detail, subsequent dimensions accelerated) | 4–6 | Dimensions populated |
| S6-G3 | Fact load implementation with surrogate key resolution (joins to dimensions for key lookup) | 3–5 | Fact populated for sources 3, 4, 5 |
| S6-G4 | Reconciliation queries — fact row totals match expected per source | 1 | Reconciliation pass |
| S6-G5 | Code review pass and refactor | 2 | Final notebook |
| S6-G6 | Defense rehearsal — full Gold layer narrative including IPC and IPI contributions from Sprint 4 Dataflows | 1 | Sprint closed |

**Definition of Done.** All five dimensions populated. Fact populated from all five sources. Author can defend: surrogate key strategy, MERGE versus truncate-and-load decision, rationale for notebook implementation of Gold layer rather than Dataflow Gen2. Star schema is queryable end-to-end via T-SQL in `spi_warehouse`.

**Risk.** Sprint 6 carries the highest learning-curve density in the plan. Slippage compresses Sprint 7 only if explicitly authorized; default policy is to extend the calendar rather than compromise transformation quality. Silver and Gold logic is the artifact most likely to attract reviewer scrutiny.

---

### Sprint 7 — Master pipeline orchestration and Power BI report

**Objective.** End-to-end pipeline orchestration triggerable from a single execution, and the consumption-layer artifacts: semantic model and report.

**Tasks — Orchestration (S7A).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S7A-1 | Build `spi_pl_bronze` master pipeline (orchestrates 5 Bronze artifacts: 2 pipelines, 3 notebooks) | 2–3 | Bronze layer single-trigger |
| S7A-2 | Build `spi_pl_silver` master pipeline (orchestrates 2 Dataflows, 3 notebooks) | 2–3 | Silver layer single-trigger |
| S7A-3 | Build `spi_pl_gold` master pipeline (orchestrates 2 Dataflows, Gold notebook) | 1–2 | Gold layer single-trigger |
| S7A-4 | Build `spi_pl_master` (sequential orchestration: Bronze → Silver → Gold) | 1–2 | Full pipeline single-trigger |
| S7A-5 | End-to-end execution; logging audit | 1 | Production-ready orchestration |

**Tasks — Power BI (S7B).**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S7B-1 | Create Direct Lake semantic model on `spi_warehouse` | 1 | Model item |
| S7B-2 | Configure relationships; mark date table per Phase 4 §11 | 1–2 | Model wired |
| S7B-3 | Implement DAX measures per Phase 4 catalog | 3–5 | Measures operational |
| S7B-4 | Build six-page report per Phase 3 specification | 4–6 | Report complete |
| S7B-5 | Save as PBIP for repository inclusion | 0.5 | PBIP exported |
| S7B-6 | Defense rehearsal: full report walkthrough as stakeholder presentation | 1 | Sprint closed |

**Definition of Done.** `spi_pl_master` executes end-to-end without manual intervention. All five sources resolve into Gold. Power BI report renders all six pages. Author can present the report as a stakeholder-facing demonstration.

**Risk.** Direct Lake has specific constraints around refresh and column type behavior. Phase 4 §11 anticipates the principal cases; review precedes S7B-1 implementation.

---

### Sprint 8 — DEV→PROD deployment and portfolio capture

**Objective.** PROD workspace operational on F2 PAYG capacity (paused state). Portfolio assets — screenshots, demonstration video, exported artifacts — captured.

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S8-1 | Create `spi-spain-indicators-prod` workspace | 0.5 | PROD provisioned |
| S8-2 | Configure Fabric Deployment Pipeline: DEV → PROD binding | 1 | Pipeline ready |
| S8-3 | Configure deployment rules per Phase 4 §12.3 | 1 | Rules configured |
| S8-4 | Trigger deployment; verify artifact propagation | 1 | PROD provisioned |
| S8-5 | Execute `spi_pl_master` in PROD with `data_scope = full_history` | 2–3 | Full data resolved in PROD |
| S8-6 | Capture curated screenshots per Phase 0 §7 (8–15 images: workspace, lakehouse, warehouse, notebooks, pipelines, dataflows, semantic model, report pages) | 2–3 | `/docs/screenshots/` populated |
| S8-7 | Record demonstration video (Loom, 10–15 minutes, full E2E walkthrough) | 2–3 | Video URL captured |
| S8-8 | Migrate PROD to F2 PAYG capacity (paused) — **before trial day 53** | 1 | Permanent portfolio surface |
| S8-9 | Final smoke test in PROD on F2 PAYG capacity | 1 | Sprint closed |

**Definition of Done.** PROD environment operational on F2 PAYG (paused). Screenshots, demonstration video, and exportable artifacts all captured. Trial expiry no longer represents a risk to portfolio availability.

**Risk.** Trial day 53 is a hard deadline for Sprint 8 closure. If sprint trajectory at the end of Sprint 7 indicates this date will not be met, deferrable polish items (additional report pages, optional documentation) are deprioritized to protect the deadline.

---

### Sprint 9 — Phase 6: GitHub publication

**Objective.** Repository organized as a portfolio-grade artifact. The README functions as the landing page that converts a recruiter or prospect's first visit into a follow-up interaction.

**Tasks.**

| ID | Task | Est. (h) | Output |
|---|---|---|---|
| S9-1 | Export Fabric artifacts (notebooks, pipelines, dataflows, PBIP) into `/src/` | 2–3 | Code in repository |
| S9-2 | Author folder-level README files (`/src/notebooks/`, `/src/pipelines/`, etc.) | 2–3 | Navigable repository structure |
| S9-3 | Consolidate `lessons-learned.md` from accumulated sprint notes | 2 | Polished operational findings document |
| S9-4 | Author the main README — primary portfolio surface | 4–6 | Landing document |
| S9-5 | Embed demonstration video and curated screenshots into README | 1 | Visual narrative integrated |
| S9-6 | Final cross-check: PDF references, code links, internal navigation | 1 | Quality pass |
| S9-7 | Final defense rehearsal: 30-minute mock-interview coverage of the full project | 2 | Production-ready |

**Definition of Done.** Repository is shareable as the response to "show me your end-to-end work" without verbal preamble. The main README answers within 60 seconds: project purpose, business problem, technical approach, outcome, author. Author can sustain a 30-minute technical interview on any aspect of the project without reference material.

**Risk.** README quality is the highest-leverage artifact in the portfolio. S9-4 is non-deferrable; where time pressure emerges, S9-3 is sacrificed first.

---

## 4. Cross-Sprint Practices

### 4.1 Daily

Each working session opens with a `git pull`, review of the active task, and re-reading of the current sprint's Definition of Done. Each session closes with a commit (descriptive message), a push, and a status update on the Kanban board (✅ / 🚧 / ❌).

### 4.2 Weekly

Each Friday: 30-minute retrospective. What worked, what did not, what risks are emerging for the following week. Output appended to `lessons-learned.md`. Where a sprint has slipped, recovery does not occur through skipping defense rehearsals — the rehearsal is itself the deliverable.

### 4.3 Per artifact

Each notebook, pipeline, and dataflow carries a markdown header recording: purpose, inputs, outputs, dependencies, last-updated date. Each commit message follows the convention `[sprint-id] short description` (e.g., `[S5-Energy] implement fetch_with_retry`).

### 4.4 Defense rehearsal protocol

At the closure of each task that produces a notebook, pipeline, or dataflow:

1. The author closes the development environment and any reference documentation.
2. Three to five probing questions are posed against the artifact, mixing complexity tiers:
   - **Tier 1:** What does this artifact do?
   - **Tier 2:** Why was this implementation choice made over alternative X?
   - **Tier 3:** What changes if the source data volume increases by 100×? What is the failure mode under mid-execution Lakehouse disconnection?
3. Hesitation or hand-waving constitutes failure. The artifact is re-read; the rehearsal is repeated.

This protocol is the single most important quality gate in the plan. It is the mechanism that converts "completed code" into "owned code" — the latter being the portfolio's actual deliverable.

---

## 5. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Cross-tenant Azure SQL connection fails in Fabric | Medium | High (blocks IPI in Sprint 4) | Resolution path documented in Phase 4 §9. Buffer allocated in Sprint 3. If unresolved, IPI defers to mid-Sprint 4 without cascading impact. |
| `xlrd` unavailable in Fabric Spark runtime | Medium | Medium (blocks Construction notebook) | Verified during Sprint 3 toy notebook. Fabric Environment installation per Phase 4 §3.7 is the resolution. |
| Trial expiry before Sprint 8 closure | Low (under this plan) | Critical | Sprint 8 closure must occur before trial day 53. F2 PAYG migration is the irreversible safety gate. |
| Sustained author productivity decrease (multi-week) | Medium | Medium | Buffer is built into estimates. Honest re-estimation and scope reduction are acceptable responses; compromising the working dynamic (delegating code production to AI assistance) is not. |
| Power BI report scope creep | Medium | Low | Phase 3 specifies six pages; six pages are built. Polish iteration occurs post-publication. |
| Defense rehearsals deprioritized under time pressure | High | Critical | The rehearsal is the portfolio differentiator. It is non-optional regardless of schedule pressure. |
| Perfectionism on README delays Sprint 9 closure | Medium | Low | README time-boxed at 6 hours for v1; polish iteration occurs after publication. |

---

## 6. Definition of Project Done

The project is considered complete when **all** of the following conditions are satisfied:

- [ ] `spi-spain-indicators` GitHub repository is public and organized per Phase 0 §9.
- [ ] All Fabric components (Lakehouse, Pipelines, Notebooks, Dataflows Gen2, Warehouse, Power BI) are present and used where architecturally appropriate.
- [ ] All five sources resolve into `spi_fact_indicators` end-to-end via a single pipeline trigger.
- [ ] PROD environment runs on F2 PAYG capacity (paused) and is available for live demonstration.
- [ ] The main README answers project purpose, problem, approach, outcome, and author within 60 seconds of reading.
- [ ] Demonstration video (10–15 minutes) is embedded in the README.
- [ ] Curated screenshots (8–15 images) populate `/docs/screenshots/`.
- [ ] `lessons-learned.md` is a polished operational findings document, not a notes dump.
- [ ] The author can defend any single artifact in the repository in under five minutes, without reference material, in front of a technical interviewer.
- [ ] At least one full mock-interview rehearsal of 30+ minutes has been completed.

When the above checklist is fully satisfied, the project is considered ready to function as the centerpiece of the freelance portfolio.

---

## 7. Strategic Outlook

The intended outcome of this project, measured at six months post-publication, is operational rather than aspirational. A freelance prospect requesting evidence of end-to-end Microsoft Fabric capability receives a single repository URL. Within five minutes, the prospect has read the README, viewed the demonstration video, browsed two notebooks, and inspected the Power BI report. The expected next message from the prospect is a request for a call.

The plan defined in this document is engineered to produce that outcome.

---

## 8. Changelog

| Version | Date | Notes |
|---|---|---|
| 1.0 | May 2026 | Initial plan. Authored prior to Sprint 0 kickoff. Living document — sprint outcomes update Sections 3, 4, 5 in place. Estimate revisions are recorded with explicit notes. |
