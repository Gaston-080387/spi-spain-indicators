# Prerequisites

One-time setup scripts that prepare the environment before the Fabric pipeline
(Phase 5) can run. These are not part of the productive pipeline — they exist
to bootstrap the environment with realistic source data.

## Components

| Component | Purpose |
|-----------|---------|
| `ipi-azure-sql-load/` | Loads INE IPI CSV into Azure SQL Database, simulating a transactional source for the IPI ingestion path |

## When are these executed?

Once, before Phase 5 development begins. After the Fabric pipeline is operational,
these scripts are not re-run unless the underlying infrastructure is recreated.
