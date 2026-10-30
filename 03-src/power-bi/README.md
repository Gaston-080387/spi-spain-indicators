# Power BI report

Power BI Project (PBIP): the semantic model in TMDL and the report in PBIR,
both plain text and reviewable in Git. Built in Power BI Desktop in **Import
mode** from the `spi_warehouse` SQL endpoint (ADR-020).

## Contents

| Path | Content |
|---|---|
| `spi_spain_indicators.pbip` | Open this file in Power BI Desktop |
| `spi_spain_indicators.SemanticModel/` | Tables, relationships, 19 DAX measures (`definition/tables/_Measures.tmdl`) |
| `spi_spain_indicators.Report/` | Six pages, visuals, theme and backgrounds |
| `assets/` | Source files of the theme (`spi_theme.json`) and page backgrounds (SVG) |

## Pages

Overview · Consumer prices (IPC) · Industrial production (IPI) · Electricity
demand · Construction · Tax. Region and period slicers are synced across
pages. Screenshots: `01-docs/evidence/09_pbi_overview.png` to `14_pbi_tax.png`.

## Model

- **Tables:** `Fact Indicators`, `Indicator`, `Region`, `Calendar`, `Source`,
  `_Measures`, `_Refresh` (refresh timestamp shown in each page header).
- **Relationships** filter one way, dimension → fact; measures read the fact
  table.
- **`Value`** averages index sources (IPC, IPI) and sums flow sources
  (Energy, Construction, Tax). It returns blank when more than one region,
  source or index is in scope.
- **Time intelligence** uses `Calendar[month_index]` (year × 12 + month): the
  calendar is monthly and cannot be marked as a date table.

## Opening and refreshing

The imported data (`.pbi/cache.abf`) is not in Git, so a fresh clone opens
with an empty model. To load data:

1. Resume the Fabric capacity and run `spi_pl_master` if needed.
2. **Transform data → Data source settings → Change Source**: the
   `spi_warehouse` SQL endpoint of your workspace.
3. Sign in with a Microsoft (Entra) account → **Refresh**.

For an offline look without Fabric, download the `.pbix` from the GitHub
Release.
