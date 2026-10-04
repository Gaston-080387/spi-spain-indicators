-- =====================================================================
-- SPI  |  Logging Table DDL  |  Warehouse : spi_warehouse
-- Sprint 3 - Task S3-5   (Phase 4 §10.1)
--
-- Execution context: run ONCE, as T-SQL, in the spi_warehouse SQL editor.
--
-- Lives in the Warehouse, not the Lakehouse (ADR-009): the Lakehouse SQL
-- analytics endpoint is read-only, so T-SQL cannot INSERT there. Phase 4
-- §2.3.3 places it in spi_lakehouse; ADR-009 supersedes that.
--
-- Rows are written by Script activities in the pipelines, chained On
-- completion after each Copy or Notebook activity (ADR-009, 2026-09-30
-- addendum). Notebooks do not write here.
-- =====================================================================

CREATE TABLE dbo.spi_log_pipeline_execution (
    run_id           VARCHAR(36)   NOT NULL,  -- GUID from master pipeline
    pipeline_name    VARCHAR(100)  NOT NULL,  -- e.g. spi_pl_bronze_energy
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
--     SELECT TOP 1 run_id FROM spi_log_pipeline_execution
--     ORDER BY start_time DESC
-- )
-- ORDER BY start_time;

-- Recent failures across all runs
-- SELECT TOP 20 pipeline_name, source, start_time, error_message
-- FROM spi_log_pipeline_execution
-- WHERE status = 'failed'
-- ORDER BY start_time DESC;
