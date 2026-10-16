# Documentation

Formal documentation for this project. The phase PDFs are deliverables-grade
documents, equivalent to what would be delivered to a real client.

## Contents

### Formal phase deliverables

| File | Phase | Content |
|------|-------|---------|
| `phase0_project_brief.pdf` | 0 | Context, scope, strategy |
| `phase1_requirements.pdf` | 1 | Requirements + source catalog |
| `phase2_architecture.pdf` | 2 | Architecture design + data flow |
| `phase3_functional.pdf` | 3 | Functional specification |
| `phase4_technical.pdf` | 4 | Technical specification |

The phase documents are frozen. Where implementation diverges from them, the
ADR log records the deviation and wins.

### Living documentation

| File | Content |
|------|---------|
| `spi_adr_log.md` | Architecture decision records: every decision and deviation from the phase documents, with dated addenda and validations. The authoritative source for current design |
| `phase5_dev_plan.md` | Development plan: sprints, tasks, status, replans and risk register |
| `lessons-learned.md` | Platform findings discovered during implementation (Fabric, Warehouse T-SQL, Dataflows, notebooks, sources) |
| `rebuild_checklist.md` | Hard-coded IDs and settings to replace when the workspace is rebuilt on the paid capacity (Sprint 8, ADR-019) |
| `spi_pl_bronze (diagram).png` | Early diagram of `spi_pl_bronze` (ADR-007 design, 2026-08). Superseded: the pipeline now invokes the per-source pipelines (ADR-018) |

## Versioning

Phase PDFs are versioned individually. Each PDF has a "Document version" field
on its first page and a "Changelog" section at the end (from v1.1 onwards).
