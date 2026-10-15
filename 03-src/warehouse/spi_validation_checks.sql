/* =====================================================================
   SPI  |  Validation checks  |  Fabric Warehouse: spi_warehouse
   Sprint 7

   Read-only checks on the Gold star schema after a master run
   (spi_pl_master) or a spi_pl_gold run. Run each query in the
   spi_warehouse SQL editor. Every check states its expected result.

   Checks:
     1. Fact rows per source equal the Silver row counts.
     2. No duplicate fact keys
        (indicator_key, region_key, calendar_key, source_key).
     3. No orphan calendar keys: every fact calendar_key has a row in
        spi_dim_calendar (ADR-010, addendum 2026-10-15).
     4. No orphan indicator keys.
     5. No orphan region keys.
     6. spi_dim_calendar covers 1975-01 to December of the current year.

   Checks 3 to 5 guard the IPC and IPI Gold dataflows. They resolve keys
   in M, and the Warehouse does not enforce foreign keys, so a key with
   no dimension row loads without error. dbo.spi_sp_gold_load throws on
   a missing key, so Energy, Construction and Tax cannot load one.

   No null-key check: the fact's key columns are NOT NULL
   (spi_gold_ddl.sql), and Fabric Warehouse enforces NOT NULL.

   Check 1 reads Silver through the SQL analytics endpoint, which may
   lag behind Silver writes (ADR-014, point (b)). Run it after a
   spi_pl_gold run, whose nb_gold_refresh_sql_endpoint refreshes the
   three procedure-read tables. The IPC and IPI Silver tables are not
   in that refresh.
   ===================================================================== */


/* 1. Fact rows per source vs Silver ------------------------------------
   Expected: fact_rows = silver_rows for all five sources. */

SELECT s.source_key,
       s.source_code,
       COALESCE(f.fact_rows, 0) AS fact_rows,
       s.silver_rows,
       COALESCE(f.fact_rows, 0) - s.silver_rows AS difference
FROM (
    SELECT 1 AS source_key, 'IPC' AS source_code,
           (SELECT COUNT(*) FROM spi_lakehouse.dbo.spi_silver_ipc_cleaned) AS silver_rows
    UNION ALL
    SELECT 2, 'IPI',
           (SELECT COUNT(*) FROM spi_lakehouse.dbo.spi_silver_ipi_cleaned)
    UNION ALL
    SELECT 3, 'ENERGY',
           (SELECT COUNT(*) FROM spi_lakehouse.dbo.spi_silver_energy_cleaned)
    UNION ALL
    SELECT 4, 'CONSTRUCTION',
           (SELECT COUNT(*) FROM spi_lakehouse.dbo.spi_silver_construction_cleaned)
    UNION ALL
    SELECT 5, 'TAX',
           (SELECT COUNT(*) FROM spi_lakehouse.dbo.spi_silver_tax_cleaned)
) AS s
LEFT JOIN (
    SELECT source_key, COUNT(*) AS fact_rows
    FROM dbo.spi_fact_indicators
    GROUP BY source_key
) AS f
    ON f.source_key = s.source_key
ORDER BY s.source_key;


/* 2. Duplicate fact keys ------------------------------------------------
   Expected: no rows. Constraints are not enforced in the Warehouse;
   uniqueness is the load's responsibility (ADR-010). */

SELECT indicator_key, region_key, calendar_key, source_key,
       COUNT(*) AS row_count
FROM dbo.spi_fact_indicators
GROUP BY indicator_key, region_key, calendar_key, source_key
HAVING COUNT(*) > 1;


/* 3. Orphan calendar keys -----------------------------------------------
   Expected: no rows. The IPC and IPI Gold dataflows compute
   calendar_key as year * 100 + month instead of looking it up, so a
   period outside spi_dim_calendar loads without error (ADR-010,
   addendum 2026-10-15). */

SELECT f.source_key,
       COUNT(*)            AS orphan_rows,
       MIN(f.calendar_key) AS first_calendar_key,
       MAX(f.calendar_key) AS last_calendar_key
FROM dbo.spi_fact_indicators AS f
LEFT JOIN dbo.spi_dim_calendar AS c
    ON c.calendar_key = f.calendar_key
WHERE c.calendar_key IS NULL
GROUP BY f.source_key
ORDER BY f.source_key;


/* 4. Orphan indicator keys ----------------------------------------------
   Expected: no rows. */

SELECT f.source_key,
       COUNT(*)             AS orphan_rows,
       MIN(f.indicator_key) AS first_indicator_key,
       MAX(f.indicator_key) AS last_indicator_key
FROM dbo.spi_fact_indicators AS f
LEFT JOIN dbo.spi_dim_indicator AS i
    ON i.indicator_key = f.indicator_key
WHERE i.indicator_key IS NULL
GROUP BY f.source_key
ORDER BY f.source_key;


/* 5. Orphan region keys -------------------------------------------------
   Expected: no rows. */

SELECT f.source_key,
       COUNT(*)          AS orphan_rows,
       MIN(f.region_key) AS first_region_key,
       MAX(f.region_key) AS last_region_key
FROM dbo.spi_fact_indicators AS f
LEFT JOIN dbo.spi_dim_region AS r
    ON r.region_key = f.region_key
WHERE r.region_key IS NULL
GROUP BY f.source_key
ORDER BY f.source_key;


/* 6. Calendar range -----------------------------------------------------
   Expected: actual = expected in all three pairs. spi_df_gold_dimensions
   generates 1975-01 to December of the year of its last refresh
   (ADR-010, addendum 2026-10-15). A mismatch in a new year means the
   dimension dataflow has not been refreshed since the year changed. */

SELECT MIN(calendar_key)                    AS first_key,
       197501                               AS expected_first_key,
       MAX(calendar_key)                    AS last_key,
       YEAR(GETDATE()) * 100 + 12           AS expected_last_key,
       COUNT(*)                             AS calendar_rows,
       (YEAR(GETDATE()) - 1975 + 1) * 12    AS expected_calendar_rows
FROM dbo.spi_dim_calendar;
