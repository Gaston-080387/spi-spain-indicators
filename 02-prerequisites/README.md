# Prerequisites

One-time setup scripts that prepare the ground before the Fabric pipeline
(Phase 5) can run. These are not part of the productive pipeline. One script
bootstraps Azure SQL with realistic source data so the pipeline has a
transactional source to read; the other three are local validation implementations of the Bronze notebooks, each writing a Parquet snapshot that serves as the Bronze extraction baseline for later reconciliation against the Fabric Bronze output[]

## Prerequisites

Only `ipi-azure-sql-load/` needs authentication — it writes to Azure SQL via
`DefaultAzureCredential`, which relies on the local Azure CLI session. Run
`az login` before executing it. Azure CLI refresh tokens expire after 90 days
of inactivity, so a session that worked on a previous run may need renewing;
the failure surfaces as `AADSTS700082`.

The other three scripts download from public endpoints (REE, MITMA, AEAT) and
require no authentication.

## Components

| Component | Purpose |
|-----------|---------|
| `ipi-azure-sql-load/` | Loads INE IPI CSV into Azure SQL Database, simulating a transactional source for the IPI ingestion path |
| `ree-api-bronze-load/` | Extracts REE electricity-demand data from the REE REST API (three regions, monthly, 2014–present) and writes a Parquet snapshot as the Energy Bronze extraction baseline |
| `cons-xls-bronze-load/` | Downloads the four MITMA construction XLS files, combines them into one DataFrame, and writes a Parquet snapshot as the Construction Bronze extraction baseline |
| `tax-xlsx-bronze-load/` | Downloads the AEAT multi-sheet tax-revenue XLSX, reads the `datos_delegaciones` sheet, and writes a Parquet snapshot as the Tax Bronze extraction baseline |

## When are these executed?

Once, before Phase 5 development begins. After the Fabric pipeline is operational,
these scripts are not re-run unless the underlying infrastructure is recreated —
or, for the Parquet baselines, unless a fresh extraction baseline is needed.
