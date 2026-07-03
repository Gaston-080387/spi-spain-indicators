/* =====================================================================
   SPI  |  Gold Layer DDL  |  Fabric Warehouse: spi_warehouse
   Sprint 3 - Task S3-4
   Star schema: 1 fact + 4 dimensions, all in the dbo schema.

   Target engine: Microsoft Fabric Warehouse (T-SQL / Polaris).
   Default DB collation: Latin1_General_100_BIN2_UTF8 (UTF-8).
   Run order: dimensions first, seeds next, fact last.

   ---------------------------------------------------------------------
   DEVIATIONS FROM PHASE 4 SS4 (frozen doc) - recorded in the decision log
   ---------------------------------------------------------------------
   ADR-002  Derived measures (YoY / MoM / YTD / QTD) are modeled as DAX
            time-intelligence, NOT materialized as fact rows.
            Rationale: SPI is consumed by a single surface (Power BI via
            Direct Lake). The multi-surface driver that justified
            materialization in the Murcia production system does not exist
            here. Consequence: spi_dim_measure and fact.measure_key are
            removed; fact grain drops from 5 to 4 dimensions.

   ADR-003  INE files (IPC, IPI) ship 4 measures; only the base index is
            loaded to the model, for grain consistency across the 5
            sources. The 3 official INE variations remain in Bronze and are
            used to reconcile the DAX-computed derivations.

   ADR-004  NVARCHAR -> VARCHAR. Fabric Warehouse does NOT persist NVARCHAR
            in tables (Microsoft Learn: fabric/data-warehouse/data-types).
            VARCHAR under the default UTF-8 collation stores Unicode
            natively (e.g. "Cataluna" with tilde). The frozen SS4 DDL uses
            NVARCHAR throughout and would fail at CREATE TABLE as written.

   Fabric Warehouse constraints (apply to all objects below):
     - PK / FK are declared NONCLUSTERED ... NOT ENFORCED. Fabric does not
       enforce constraints; they document the model and let the Power BI
       semantic model auto-detect relationships.
     - No IDENTITY in Fabric Warehouse. Surrogate keys are assigned
       explicitly: fixed dimensions via the seed INSERTs below; calendar
       and indicator are populated programmatically in Phase 5.
   ===================================================================== */


/* =====================================================================
   1. DIMENSIONS  (no FKs - created first)
   ===================================================================== */

CREATE TABLE dbo.spi_dim_indicator (
    indicator_key       INT           NOT NULL,
    indicator_name      VARCHAR(200)  NOT NULL,
    indicator_category  VARCHAR(200)  NOT NULL,
    domain              VARCHAR(100)  NOT NULL,
    unit_of_measure     VARCHAR(100)  NOT NULL,
    frequency           VARCHAR(50)   NOT NULL,
    CONSTRAINT PK_dim_indicator PRIMARY KEY NONCLUSTERED (indicator_key) NOT ENFORCED
);
GO

CREATE TABLE dbo.spi_dim_region (
    region_key   INT          NOT NULL,
    region_code  VARCHAR(3)   NOT NULL,
    region_name  VARCHAR(50)  NOT NULL,
    region_type  VARCHAR(50)  NOT NULL,
    CONSTRAINT PK_dim_region PRIMARY KEY NONCLUSTERED (region_key) NOT ENFORCED
);
GO

CREATE TABLE dbo.spi_dim_calendar (
    calendar_key     INT          NOT NULL,   -- smart surrogate: YYYYMM
    [year]           INT          NOT NULL,
    [month]          INT          NOT NULL,
    month_name       VARCHAR(20)  NOT NULL,
    [quarter]        INT          NOT NULL,
    year_month       VARCHAR(7)   NOT NULL,   -- 'YYYY-MM'
    is_current_year  BIT          NOT NULL,
    CONSTRAINT PK_dim_calendar PRIMARY KEY NONCLUSTERED (calendar_key) NOT ENFORCED
);
GO

CREATE TABLE dbo.spi_dim_source (
    source_key          INT           NOT NULL,
    source_code         VARCHAR(20)   NOT NULL,
    source_name         VARCHAR(200)  NOT NULL,
    source_institution  VARCHAR(100)  NOT NULL,
    source_domain       VARCHAR(100)  NOT NULL,
    source_url          VARCHAR(500)  NULL,
    update_frequency    VARCHAR(50)   NOT NULL,
    CONSTRAINT PK_dim_source PRIMARY KEY NONCLUSTERED (source_key) NOT ENFORCED
);
GO


/* =====================================================================
   2. SEED DATA  (fixed dimensions - inserted once)
   ===================================================================== */

INSERT INTO dbo.spi_dim_region
    (region_key, region_code, region_name, region_type)
VALUES
    (1, 'NAC', 'Nacional', 'Aggregated National'),
    (2, 'CAT', 'Cataluña', 'Autonomous Community'),
    (3, 'MAD', 'Madrid',   'Autonomous Community');
GO

/* update_frequency defaulted to 'Monthly' (all five indicators are monthly).
   source_url left NULL for now - populate when the source catalog is final. */
INSERT INTO dbo.spi_dim_source
    (source_key, source_code, source_name, source_institution, source_domain, source_url, update_frequency)
VALUES
    (1, 'IPC',          'Consumer Price Index',        'INE',          'Consumer Prices',       NULL, 'Monthly'),
    (2, 'IPI',          'Industrial Production Index', 'INE',          'Industrial Production', NULL, 'Monthly'),
    (3, 'ENERGY',       'Electricity Demand',          'REE (Redeia)', 'Energy',                NULL, 'Monthly'),
    (4, 'CONSTRUCTION', 'Public Construction Tenders', 'MITMA',        'Construction',          NULL, 'Monthly'),
    (5, 'TAX',          'Tax Revenue by Delegations',  'AEAT',         'Tax Revenue',           NULL, 'Monthly');
GO

/* spi_dim_calendar is populated programmatically (2000 -> current year,
   ~324 rows) in Phase 5. spi_dim_indicator is populated by the Gold
   notebook as sources are processed. */


/* =====================================================================
   3. FACT TABLE  (references all dimensions - created last)
   ===================================================================== */

CREATE TABLE dbo.spi_fact_indicators (
    indicator_key    INT            NOT NULL,
    region_key       INT            NOT NULL,
    calendar_key     INT            NOT NULL,
    source_key       INT            NOT NULL,
    indicator_value  DECIMAL(18,4)  NOT NULL,   -- base index; NOT NULL (derived measures are DAX, per ADR-002)
    CONSTRAINT PK_fact_indicators PRIMARY KEY NONCLUSTERED (
        indicator_key, region_key, calendar_key, source_key
    ) NOT ENFORCED,
    CONSTRAINT FK_fact_indicator FOREIGN KEY (indicator_key)
        REFERENCES dbo.spi_dim_indicator (indicator_key) NOT ENFORCED,
    CONSTRAINT FK_fact_region FOREIGN KEY (region_key)
        REFERENCES dbo.spi_dim_region (region_key) NOT ENFORCED,
    CONSTRAINT FK_fact_calendar FOREIGN KEY (calendar_key)
        REFERENCES dbo.spi_dim_calendar (calendar_key) NOT ENFORCED,
    CONSTRAINT FK_fact_source FOREIGN KEY (source_key)
        REFERENCES dbo.spi_dim_source (source_key) NOT ENFORCED
);
GO


/* =====================================================================
   4. POST-CREATE SANITY CHECK  (optional - run after execution)
   ===================================================================== */

-- SELECT 'spi_dim_region'  AS table_name, COUNT(*) AS row_count FROM dbo.spi_dim_region
-- UNION ALL SELECT 'spi_dim_source',    COUNT(*) FROM dbo.spi_dim_source
-- UNION ALL SELECT 'spi_dim_calendar',  COUNT(*) FROM dbo.spi_dim_calendar
-- UNION ALL SELECT 'spi_dim_indicator', COUNT(*) FROM dbo.spi_dim_indicator
-- UNION ALL SELECT 'spi_fact_indicators', COUNT(*) FROM dbo.spi_fact_indicators;
