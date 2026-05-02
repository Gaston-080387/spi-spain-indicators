# Notebooks

PySpark and Python notebooks for the Microsoft Fabric pipeline.

## Layers (subfolders to be created during Phase 5)

- `bronze/` — Raw ingestion notebooks (Energy API, Construction XLS, Tax XLSX)
- `silver/` — Cleansing, type enforcement, deduplication
- `gold/` — Mapping to star schema, derived measures (YoY, MoM, YTD, QTD)

## Naming convention

Notebooks follow the convention defined in Phase 2 architecture document:

`spi_nb_<layer>_<source>` — e.g., `spi_nb_bronze_energy`, `spi_nb_silver_construction`

## Status

🚧 Empty — populated during Phase 5 development.
