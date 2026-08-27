-- =====================================================================
-- SPI  |  Logging Table DDL  |  Lakehouse (Delta) : spi_lakehouse
-- Sprint 3 - Task S3-5   (Phase 4 §10.1)
--
-- Execution context: run ONCE, in a Fabric Lakehouse notebook cell, as
-- Spark SQL (a %%sql cell, or spark.sql("""...""")). The notebook must be
-- attached to spi_lakehouse as its default lakehouse.
--
-- Lives in the Lakehouse, not the Warehouse: this is operational metadata,
-- not analytical data (Phase 4 §10). Every notebook and pipeline writes here.
-- =====================================================================

CREATE TABLE dbo.spi_log_pipeline_execution (
    run_id           VARCHAR(36)   NOT NULL,  -- GUID from master pipeline
    pipeline_name    VARCHAR(100)  NOT NULL,  -- e.g. spi_nb_bronze_energy
    layer            VARCHAR(10)   NOT NULL,  -- bronze | silver | gold
    source           VARCHAR(20)   NOT NULL,  -- ipc | ipi | energy | construction | tax | all
    status           VARCHAR(10)   NOT NULL,  -- running | success | failed
    start_time       DATETIME2(6)  NOT NULL,  -- UTC
    end_time         DATETIME2(6)  NULL,      -- UTC; null while running
    error_message    VARCHAR(4000) NULL,      -- exception / DQ summary; null on success
    rows_processed   INT           NULL       -- null while running / on failure
);


-- =====================================================================
-- Diagnostic queries (Phase 4 §10.4)
-- ADR-005: identify the latest run by start_time, NOT by MAX(run_id).
--          run_id is a GUID string; GUIDs are not monotonic, so
--          MAX(run_id) returns an arbitrary run, not the most recent one.
-- =====================================================================

-- Last run summary
-- SELECT pipeline_name, layer, source, status, start_time, end_time, rows_processed
-- FROM spi_log_pipeline_execution
-- WHERE run_id = (
--     SELECT run_id FROM spi_log_pipeline_execution
--     ORDER BY start_time DESC
--     LIMIT 1
-- )
-- ORDER BY start_time;

-- Recent failures across all runs
-- SELECT pipeline_name, source, start_time, error_message
-- FROM spi_log_pipeline_execution
-- WHERE status = 'failed'
-- ORDER BY start_time DESC
-- LIMIT 20;
