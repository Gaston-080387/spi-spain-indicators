# Notebooks

Fabric notebooks for the three sources that do not use Dataflows (Energy,
Construction, Tax). All six run on the **Python** runtime: pandas, no Spark
session. All tables are in `spi_lakehouse`.

| Notebook | Runtime | Source | Target table | ADR |
|---|---|---|---|---|
| `bronze/spi_nb_bronze_energy` | Python | REE REST API | `spi_bronze_energy_raw` | ADR-012 |
| `bronze/spi_nb_bronze_construction` | Python | MITMA, 4 XLS files | `spi_bronze_construction_raw` | ADR-012, ADR-013 |
| `bronze/spi_nb_bronze_tax` | Python | AEAT XLSX | `spi_bronze_tax_raw` | ADR-012, ADR-013 (Tax addendum) |
| `silver/spi_nb_silver_energy` | Python | `spi_bronze_energy_raw` | `spi_silver_energy_cleaned` | ADR-012 (Silver addendum), ADR-015 |
| `silver/spi_nb_silver_construction` | Python | `spi_bronze_construction_raw` | `spi_silver_construction_cleaned` | ADR-012 (Silver addendum), ADR-016 |
| `silver/spi_nb_silver_tax` | Python | `spi_bronze_tax_raw` | `spi_silver_tax_cleaned` | ADR-012 (Silver addendum), ADR-017 |

Each notebook runs from its pipeline (`../pipelines/`), which logs the run. The
notebooks do not write log rows (ADR-009, 2026-09-30 addendum).

There is no Gold notebook. Gold for these sources is the stored procedure
`dbo.spi_sp_gold_load` (ADR-014, `../warehouse/`).

Naming: `spi_nb_<layer>_<source>`.
