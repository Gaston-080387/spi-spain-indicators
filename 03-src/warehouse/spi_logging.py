"""
spi_logging.py — centralized execution-logging helper for SPI.

Every notebook (and pipeline, via its own activities) writes to the single
Lakehouse table `spi_log_pipeline_execution` created in
03-src/lakehouse/spi_log_table_ddl.sql.

Three functions, called at fixed points of a notebook's main block:

    from spi_logging import log_start, log_end_success, log_end_failure

    run_id = "<injected by the master pipeline parameter>"
    pipeline_name = "spi_nb_bronze_energy"

    log_start(run_id, pipeline_name, layer="bronze", source="energy")
    try:
        rows = main()
        log_end_success(run_id, pipeline_name, rows)
    except Exception as e:
        log_end_failure(run_id, pipeline_name, str(e))
        raise

Requirements:
    - An active SparkSession (present by default in Fabric notebooks).
    - The notebook attached to `spi_lakehouse` as its default lakehouse.
    - Fabric Spark session timezone is UTC by default, so the engine-stamped
      timestamps below are UTC (Phase 4 §10).

Included in each notebook via `%run` of the utility notebook, or by adding
this file to the notebook's resources.
"""

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    TimestampType,
    LongType,
)
from delta.tables import DeltaTable

LOG_TABLE = "spi_log_pipeline_execution"

_LOG_SCHEMA = StructType([
    StructField("run_id",         StringType(),    True),
    StructField("pipeline_name",  StringType(),    True),
    StructField("layer",          StringType(),    True),
    StructField("source",         StringType(),    True),
    StructField("status",         StringType(),    True),
    StructField("start_time",     TimestampType(), True),
    StructField("end_time",       TimestampType(), True),
    StructField("error_message",  StringType(),    True),
    StructField("rows_processed", LongType(),      True),
])


def _spark() -> SparkSession:
    return SparkSession.getActiveSession()


def log_start(run_id: str, pipeline_name: str, layer: str, source: str) -> None:
    """Insert a 'running' row at the start of an execution.

    start_time is stamped by the engine (F.current_timestamp), so it does not
    depend on the driver clock. end_time, error_message and rows_processed are
    left null and set when the run closes.
    """
    spark = _spark()
    row = [(run_id, pipeline_name, layer, source, "running", None, None, None, None)]
    df = (
        spark.createDataFrame(row, schema=_LOG_SCHEMA)
             .withColumn("start_time", F.current_timestamp())
    )
    df.write.format("delta").mode("append").saveAsTable(LOG_TABLE)


def log_end_success(run_id: str, pipeline_name: str, rows_processed: int) -> None:
    """Close the 'running' row for this run as 'success' (happy path)."""
    _close_run(
        run_id,
        pipeline_name,
        {
            "status":         F.lit("success"),
            "end_time":       F.current_timestamp(),
            "rows_processed": F.lit(int(rows_processed)),
        },
    )


def log_end_failure(run_id: str, pipeline_name: str, error_message: str) -> None:
    """Close the 'running' row for this run as 'failed' (exception handler)."""
    _close_run(
        run_id,
        pipeline_name,
        {
            "status":        F.lit("failed"),
            "end_time":      F.current_timestamp(),
            "error_message": F.lit(error_message),
        },
    )


def _close_run(run_id: str, pipeline_name: str, set_values: dict) -> None:
    """Update the single 'running' row matching (run_id, pipeline_name).

    Uses the Delta table API with column expressions (F.lit / F.current_timestamp)
    rather than a string-built UPDATE. This escapes values safely — important for
    error_message, which routinely contains quotes and newlines.
    """
    spark = _spark()
    log = DeltaTable.forName(spark, LOG_TABLE)
    condition = (
        (F.col("run_id") == run_id)
        & (F.col("pipeline_name") == pipeline_name)
        & (F.col("status") == "running")
    )
    log.update(condition=condition, set=set_values)
