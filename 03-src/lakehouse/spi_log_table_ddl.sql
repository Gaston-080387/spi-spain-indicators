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

CREATE TABLE IF NOT EXISTS spi_log_pipeline_execution (
    run_id          STRING,      -- GUID from the master pipeline, propagated to all children
    pipeline_name   STRING,      -- pipeline or notebook identifier (e.g. spi_nb_bronze_energy)
    layer           STRING,      -- bronze | silver | gold
    source          STRING,      -- ipc | ipi | energy | construction | tax | all
    status          STRING,      -- running | success | failed
    start_time      TIMESTAMP,   -- UTC (Fabric Spark session default is UTC)
    end_time        TIMESTAMP,   -- UTC; null while running
    error_message   STRING,      -- exception / DQ summary; null on success
    rows_processed  BIGINT       -- rows written by this execution; null while running / on failure
) USING DELTA;


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
