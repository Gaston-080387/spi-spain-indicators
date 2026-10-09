# Source — Productive Pipeline Code

Code that runs in the Microsoft Fabric workspace.

| Folder | Content |
|---|---|
| `pipelines/` | Data Pipelines (exported JSON): Bronze for all five sources, Silver for Energy, Construction and Tax |
| `notebooks/` | Python notebooks for Energy, Construction and Tax: `bronze/`, `silver/` |
| `dataflows/` | Dataflows Gen2 (exported M): Silver and Gold for IPC and IPI, and the dimensions |
| `warehouse/` | T-SQL for `spi_warehouse`: Gold DDL, log table DDL, `dbo.spi_sp_gold_load` |
| `power-bi/` | Power BI report (Sprint 7) |

Each folder's README lists its files.
