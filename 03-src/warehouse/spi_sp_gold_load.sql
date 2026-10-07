/* =====================================================================
   SPI  |  Gold load  |  Fabric Warehouse: spi_warehouse
   Procedure: dbo.spi_sp_gold_load
   Sprint 6

   Loads spi_fact_indicators for Energy, Construction and Tax from their
   Silver tables in spi_lakehouse, read by three-part name. Replaces the
   Gold notebook spi_nb_gold_load (ADR-014; cross-database read verified
   in the 2026-10-06 addendum).

   Steps:
     1. Build #gold_stage: the three Silver tables (UNION ALL), each
        tagged with its source_code. All four keys are resolved by
        LEFT JOIN (ADR-010 §3). indicator_key matches on
        (indicator_category, domain), with domain = the source's
        source_domain (ADR-010, addendum 2026-10-06). calendar_key is
        looked up in spi_dim_calendar, never computed (decision
        2026-10-07).
     2. Validate #gold_stage. THROW on null keys, a row count different
        from Silver (join fan-out), duplicate fact keys, or a source
        with no rows (an empty Silver read must fail, not load nothing;
        ADR-014 point (b)). The fact is not touched until every check
        passes.
     3. One transaction: DELETE the fact rows of the source_keys in
        #gold_stage, then INSERT #gold_stage (ADR-010 delete-by-source
        + append; atomic per ADR-014). On error: ROLLBACK, re-THROW.
     4. Return one row: rows_deleted, rows_inserted, rows per source.

   Does not:
     - Write to any dimension. spi_dim_indicator, spi_dim_region and
       spi_dim_calendar belong to spi_df_gold_dimensions; spi_dim_source
       is seeded by spi_gold_ddl.sql (ADR-010 addenda 2026-10-04 and
       2026-10-06).
     - Touch IPC or IPI rows (source_key 1 and 2). They are loaded by
       spi_df_gold_ipc and spi_df_gold_ipi.
     - Refresh the SQL analytics endpoint. Silver is read as the
       endpoint sees it (ADR-014, open point (b)).
   ===================================================================== */

CREATE OR ALTER PROCEDURE dbo.spi_sp_gold_load
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @silver_rows         INT,
            @stage_rows          INT,
            @null_source_key     INT,
            @null_indicator_key  INT,
            @null_region_key     INT,
            @null_calendar_key   INT,
            @duplicate_keys      INT,
            @empty_sources       VARCHAR(100),
            @rows_deleted        INT,
            @rows_inserted       INT,
            @example             VARCHAR(500),
            @message             VARCHAR(2048);

    BEGIN TRY

        /* 1. Gold row set ------------------------------------------------ */

        DROP TABLE IF EXISTS #gold_stage;

        CREATE TABLE #gold_stage (
            source_code         VARCHAR(20)    NOT NULL,
            region_name         VARCHAR(200)   NULL,
            indicator_category  VARCHAR(200)   NULL,
            [year]              INT            NULL,
            [month]             INT            NULL,
            indicator_key       INT            NULL,
            region_key          INT            NULL,
            calendar_key        INT            NULL,
            source_key          INT            NULL,
            indicator_value     DECIMAL(18,4)  NULL
        )
        WITH (DISTRIBUTION = ROUND_ROBIN);

        INSERT INTO #gold_stage (
            source_code, region_name, indicator_category, [year], [month],
            indicator_key, region_key, calendar_key, source_key, indicator_value
        )
        SELECT
            s.source_code,
            s.region_name,
            s.indicator_category,
            s.[year],
            s.[month],
            i.indicator_key,
            r.region_key,
            c.calendar_key,
            src.source_key,
            CAST(s.indicator_value AS DECIMAL(18,4))
        FROM (
            SELECT 'ENERGY' AS source_code, region_name, indicator_category,
                   [year], [month], indicator_value
            FROM spi_lakehouse.dbo.spi_silver_energy_cleaned
            UNION ALL
            SELECT 'CONSTRUCTION', region_name, indicator_category,
                   [year], [month], indicator_value
            FROM spi_lakehouse.dbo.spi_silver_construction_cleaned
            UNION ALL
            SELECT 'TAX', region_name, indicator_category,
                   [year], [month], indicator_value
            FROM spi_lakehouse.dbo.spi_silver_tax_cleaned
        ) AS s
        LEFT JOIN dbo.spi_dim_source AS src
            ON  src.source_code = s.source_code
        LEFT JOIN dbo.spi_dim_indicator AS i
            ON  i.indicator_category = s.indicator_category
            AND i.domain             = src.source_domain
        LEFT JOIN dbo.spi_dim_region AS r
            ON  r.region_name = s.region_name
        LEFT JOIN dbo.spi_dim_calendar AS c
            ON  c.[year]  = s.[year]
            AND c.[month] = s.[month];

        SET @stage_rows = @@ROWCOUNT;

        SELECT @silver_rows =
              (SELECT COUNT(*) FROM spi_lakehouse.dbo.spi_silver_energy_cleaned)
            + (SELECT COUNT(*) FROM spi_lakehouse.dbo.spi_silver_construction_cleaned)
            + (SELECT COUNT(*) FROM spi_lakehouse.dbo.spi_silver_tax_cleaned);

        /* 2. Validation: nothing below touches the fact until all pass ---- */

        -- 2a. Null keys, counted per key type
        SELECT
            @null_source_key    = COALESCE(SUM(CASE WHEN source_key    IS NULL THEN 1 ELSE 0 END), 0),
            @null_indicator_key = COALESCE(SUM(CASE WHEN indicator_key IS NULL THEN 1 ELSE 0 END), 0),
            @null_region_key    = COALESCE(SUM(CASE WHEN region_key    IS NULL THEN 1 ELSE 0 END), 0),
            @null_calendar_key  = COALESCE(SUM(CASE WHEN calendar_key  IS NULL THEN 1 ELSE 0 END), 0)
        FROM #gold_stage;

        IF @null_source_key + @null_indicator_key + @null_region_key + @null_calendar_key > 0
        BEGIN
            SELECT TOP (1) @example = CONCAT(
                source_code, ' | ', region_name, ' | ', indicator_category,
                ' | ', [year], '-', [month])
            FROM #gold_stage
            WHERE source_key IS NULL OR indicator_key IS NULL
               OR region_key IS NULL OR calendar_key  IS NULL
            ORDER BY source_code, region_name, indicator_category, [year], [month];

            SET @message = CONCAT(
                'spi_sp_gold_load: null keys check failed. Null source_key: ', @null_source_key,
                ', indicator_key: ', @null_indicator_key,
                ', region_key: ', @null_region_key,
                ', calendar_key: ', @null_calendar_key,
                '. Example (source | region | category | year-month): ', @example);

            THROW 50001, @message, 1;
        END;

        -- 2b. Row count equals Silver: no join fan-out
        IF @stage_rows <> @silver_rows
        BEGIN
            SELECT TOP (1) @example = CONCAT(
                source_code, ' | ', region_name, ' | ', indicator_category,
                ' | ', [year], '-', [month], ' x', COUNT(*))
            FROM #gold_stage
            GROUP BY source_code, region_name, indicator_category, [year], [month]
            HAVING COUNT(*) > 1
            ORDER BY source_code, region_name, indicator_category, [year], [month];

            SET @message = CONCAT(
                'spi_sp_gold_load: row count check failed. #gold_stage rows: ', @stage_rows,
                ', Silver rows: ', @silver_rows,
                '. Example repeated Silver row (source | region | category | year-month x count): ',
                COALESCE(@example, 'none found'));

            THROW 50002, @message, 1;
        END;

        -- 2c. Fact key unique
        SELECT @duplicate_keys = COUNT(*)
        FROM (
            SELECT indicator_key
            FROM #gold_stage
            GROUP BY indicator_key, region_key, calendar_key, source_key
            HAVING COUNT(*) > 1
        ) AS d;

        IF @duplicate_keys > 0
        BEGIN
            SELECT TOP (1) @example = CONCAT(
                indicator_key, ' | ', region_key, ' | ', calendar_key,
                ' | ', source_key, ' x', COUNT(*))
            FROM #gold_stage
            GROUP BY indicator_key, region_key, calendar_key, source_key
            HAVING COUNT(*) > 1
            ORDER BY source_key, indicator_key, region_key, calendar_key;

            SET @message = CONCAT(
                'spi_sp_gold_load: unique key check failed. Duplicated keys: ', @duplicate_keys,
                '. Example (indicator | region | calendar | source x count): ', @example);

            THROW 50003, @message, 1;
        END;

        -- 2d. Every source has rows. An empty Silver read (endpoint lag,
        --     ADR-014 point (b)) must fail, not load nothing.
        SELECT @empty_sources = STRING_AGG(e.source_code, ', ')
        FROM (VALUES ('ENERGY'), ('CONSTRUCTION'), ('TAX')) AS e (source_code)
        WHERE NOT EXISTS (
            SELECT 1 FROM #gold_stage AS g WHERE g.source_code = e.source_code
        );

        IF @empty_sources IS NOT NULL
        BEGIN
            SET @message = CONCAT(
                'spi_sp_gold_load: empty source check failed. Sources with 0 rows in #gold_stage: ',
                @empty_sources);

            THROW 50004, @message, 1;
        END;

        /* 3. Delete-by-source + append, one transaction ------------------ */

        BEGIN TRANSACTION;

        DELETE FROM dbo.spi_fact_indicators
        WHERE source_key IN (SELECT DISTINCT source_key FROM #gold_stage);

        SET @rows_deleted = @@ROWCOUNT;

        INSERT INTO dbo.spi_fact_indicators (
            indicator_key, region_key, calendar_key, source_key, indicator_value
        )
        SELECT indicator_key, region_key, calendar_key, source_key, indicator_value
        FROM #gold_stage;

        SET @rows_inserted = @@ROWCOUNT;

        COMMIT TRANSACTION;

        /* 4. Result ------------------------------------------------------- */

        SELECT
            @rows_deleted                                                 AS rows_deleted,
            @rows_inserted                                                AS rows_inserted,
            SUM(CASE WHEN source_code = 'ENERGY'       THEN 1 ELSE 0 END) AS rows_energy,
            SUM(CASE WHEN source_code = 'CONSTRUCTION' THEN 1 ELSE 0 END) AS rows_construction,
            SUM(CASE WHEN source_code = 'TAX'          THEN 1 ELSE 0 END) AS rows_tax
        FROM #gold_stage;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
