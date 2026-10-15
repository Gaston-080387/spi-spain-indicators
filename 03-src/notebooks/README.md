# Notebooks

Fabric notebooks for the three sources that do not use Dataflows (Energy,
Construction, Tax), plus one Gold step. All seven run on the **Python**
runtime: no Spark session. All tables are in `spi_lakehouse`.

| Notebook | Runtime | Source | Target table | ADR |
|---|---|---|---|---|
| `bronze/spi_nb_bronze_energy` | Python | REE REST API | `spi_bronze_energy_raw` | ADR-012 |
| `bronze/spi_nb_bronze_construction` | Python | MITMA, 4 XLS files | `spi_bronze_construction_raw` | ADR-012, ADR-013 |
| `bronze/spi_nb_bronze_tax` | Python | AEAT XLSX | `spi_bronze_tax_raw` | ADR-012, ADR-013 (Tax addendum) |
| `silver/spi_nb_silver_energy` | Python | `spi_bronze_energy_raw` | `spi_silver_energy_cleaned` | ADR-012 (Silver addendum), ADR-015 |
| `silver/spi_nb_silver_construction` | Python | `spi_bronze_construction_raw` | `spi_silver_construction_cleaned` | ADR-012 (Silver addendum), ADR-016 |
| `silver/spi_nb_silver_tax` | Python | `spi_bronze_tax_raw` | `spi_silver_tax_cleaned` | ADR-012 (Silver addendum), ADR-017 |
| `gold/spi_nb_gold_refresh_sql_endpoint` | Python | The three Silver tables | None (SQL analytics endpoint metadata) | ADR-012, ADR-014 point (b) |

Each notebook runs from its pipeline (`../pipelines/`), which logs the run. The
notebooks do not write log rows (ADR-009, 2026-09-30 addendum).

Gold for these sources is the stored procedure `dbo.spi_sp_gold_load`
(ADR-014, `../warehouse/`), not a notebook. The procedure reads Silver through
the SQL analytics endpoint, which may lag behind Delta writes.
`spi_nb_gold_refresh_sql_endpoint` runs in `spi_pl_gold` before the procedure:
it refreshes the endpoint metadata for the three Silver tables through the
Fabric REST API and fails if any of them does not sync.

Naming: `spi_nb_<layer>_<source>`. The Gold notebook is not per source, so it
is named for its action: `spi_nb_gold_refresh_sql_endpoint`.
