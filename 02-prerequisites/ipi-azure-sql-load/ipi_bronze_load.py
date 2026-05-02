"""
spi_nb_bronze_ipi  —  IPI Bronze loader
========================================
Portfolio project : End-to-End Data Analytics Platform
Layer             : Bronze (raw ingestion — no transformations, no filtering)
Source            : INE CSV pre-loaded into Azure SQL Database (spi_staging)
Target            : staging_ipi_raw table (Azure SQL, spi_staging database)
Strategy          : DROP + CREATE + full reload on every run (idempotent)

Dependencies (pip install):
    pandas  pyodbc  azure-identity

ODBC driver setup (Mac M3 / ARM64 — run once):
    brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
    brew install msodbcsql18
    odbcinst -q -d -n "ODBC Driver 18 for SQL Server"   # verify registration

Authentication:
    Uses DefaultAzureCredential, which resolves credentials in this order:
      1. Environment variables (AZURE_CLIENT_ID / SECRET / TENANT_ID)
      2. Managed Identity (when running inside Azure)
      3. Azure CLI cache — primary method for local development
         Run `az login` once; token is reused for 12-24 h automatically.
    No browser popup is triggered as long as `az login` session is active.
"""

import logging
import struct
import time
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import pyodbc
from azure.identity import DefaultAzureCredential

# ──────────────────────────────────────────────────────────────────────────────
# 0. Logging
# ──────────────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("ipi_bronze")

# ──────────────────────────────────────────────────────────────────────────────
# 1. Configuration  ← only section that needs editing between environments
# ──────────────────────────────────────────────────────────────────────────────
CSV_PATH = Path(
    "/Users/gastonbaloira/Projects/Portfolio/01_spi-indicators"
    "/01-source-files/02-IPI-60272.csv"
)

SQL_SERVER   = "spi-sqlserver-gb.database.windows.net"
SQL_DATABASE = "spi_staging"
TABLE_NAME   = "staging_ipi_raw"
ODBC_DRIVER  = "ODBC Driver 18 for SQL Server"

# Azure SQL Serverless can take up to 60 s to resume from auto-pause.
# Both timeouts are set to 90 s to safely absorb the cold-start latency.
CONNECTION_TIMEOUT = 90  # seconds — passed to the ODBC connection string
LOGIN_TIMEOUT      = 90  # seconds — passed to pyodbc.connect(timeout=)

# Rows committed per batch. Batching avoids Azure SQL session timeouts that
# occur when a single large transaction stays open longer than ~10 minutes.
BATCH_SIZE = 5_000

# ──────────────────────────────────────────────────────────────────────────────
# 2. Read source CSV
# ──────────────────────────────────────────────────────────────────────────────
def read_csv(path: Path) -> pd.DataFrame:
    """
    Reads the INE IPI CSV into a DataFrame.

    Bronze pattern: all columns stored as strings (NVARCHAR in SQL).
    No type casting, no filtering, no transformations at this stage.

    Encoding: utf-8-sig strips the BOM character automatically.
    The INE file uses UTF-8 with BOM — without utf-8-sig the first column
    name arrives as 'ï»¿Comunidades...' instead of 'Comunidades...'.
    """
    log.info("Reading CSV: %s", path)
    df = pd.read_csv(
        path,
        sep=";",
        encoding="utf-8-sig",  # UTF-8 with BOM — standard for INE exports
        dtype=str,             # all columns as text (Bronze pattern)
        na_filter=False,       # preserve empty strings; do not convert to NaN
    )
    log.info("Rows read: %s  |  Columns: %s", len(df), list(df.columns))

    # Bronze metadata: lineage and ingestion timestamp added at load time
    df["_ingestion_timestamp"] = datetime.now(timezone.utc).isoformat()
    df["_source_file"] = path.name
    return df


# ──────────────────────────────────────────────────────────────────────────────
# 3. Acquire Entra ID token
# ──────────────────────────────────────────────────────────────────────────────
def get_token_bytes() -> bytes:
    """
    Acquires a Microsoft Entra ID access token scoped to Azure SQL and
    packs it into the binary format expected by pyodbc attribute 1256
    (SQL_COPT_SS_ACCESS_TOKEN).

    Token format: 4-byte little-endian length prefix + UTF-16-LE encoded token.
    Reference: https://learn.microsoft.com/en-us/sql/connect/odbc/using-azure-active-directory
    """
    log.info("Acquiring Entra ID token via DefaultAzureCredential...")
    credential = DefaultAzureCredential()
    token = credential.get_token("https://database.windows.net/.default").token
    encoded = token.encode("utf-16-le")
    token_bytes = struct.pack("<I", len(encoded)) + encoded
    log.info("Token acquired successfully.")
    return token_bytes


# ──────────────────────────────────────────────────────────────────────────────
# 4. Connect to Azure SQL
# ──────────────────────────────────────────────────────────────────────────────
def build_connection_string() -> str:
    """
    Builds the pyodbc connection string for Azure SQL with Entra-only auth.

    Key constraints:
    - SERVER must use  host,port  format — no 'tcp:' prefix (driver adds it)
    - Encrypt=yes is required for the Entra token handshake over TLS
    - TrustServerCertificate=no enforces certificate validation (production-safe)
    - Connection Timeout > 60 absorbs Serverless auto-pause resume latency
    """
    return (
        f"DRIVER={{{ODBC_DRIVER}}};"
        f"SERVER={SQL_SERVER},1433;"
        f"DATABASE={SQL_DATABASE};"
        "Encrypt=yes;"
        "TrustServerCertificate=no;"
        f"Connection Timeout={CONNECTION_TIMEOUT};"
    )


def connect(token_bytes: bytes, max_retries: int = 3) -> pyodbc.Connection:
    """
    Opens a pyodbc connection using the pre-acquired Entra ID token.

    Handles Azure SQL Serverless auto-pause automatically:
    - Error 40613 means the database is resuming from auto-pause.
    - The first connection attempt triggers the resume process.
    - Subsequent attempts (after a 30 s wait) connect once the DB is online.
    - Any other error is raised immediately without retrying.

    Typical flow with auto-pause active:
      Attempt 1 → 40613 (resume triggered) → wait 30 s
      Attempt 2 → connected
    """
    conn_str = build_connection_string()
    log.info("Connecting to %s / %s ...", SQL_SERVER, SQL_DATABASE)

    for attempt in range(1, max_retries + 1):
        try:
            t0 = time.time()
            conn = pyodbc.connect(
                conn_str,
                attrs_before={1256: token_bytes},  # SQL_COPT_SS_ACCESS_TOKEN
                timeout=LOGIN_TIMEOUT,
            )
            conn.autocommit = False
            log.info("Connected in %.1f s", time.time() - t0)
            return conn

        except pyodbc.Error as e:
            if "40613" in str(e):
                log.warning(
                    "DB is resuming from auto-pause (attempt %s/%s) — retrying in 30 s...",
                    attempt, max_retries,
                )
                time.sleep(30)
            else:
                raise  # unexpected error — surface it immediately

    raise RuntimeError(
        f"Could not connect to {SQL_SERVER}/{SQL_DATABASE} "
        f"after {max_retries} attempts. DB may be unavailable."
    )


# ──────────────────────────────────────────────────────────────────────────────
# 5. Table management
# ──────────────────────────────────────────────────────────────────────────────
def drop_table(cursor: pyodbc.Cursor) -> None:
    """
    Drops the staging table if it exists.
    Combined with create_table, this implements the full-reload Bronze strategy:
    every run produces a clean, reproducible table with no residual data.
    """
    log.info("Dropping [%s] if exists (full reload strategy)...", TABLE_NAME)
    cursor.execute(
        f"IF OBJECT_ID('{TABLE_NAME}', 'U') IS NOT NULL DROP TABLE [{TABLE_NAME}]"
    )
    cursor.connection.commit()
    log.info("Table dropped.")


def create_table(cursor: pyodbc.Cursor, df: pd.DataFrame) -> None:
    """
    Creates the staging table with all columns as NVARCHAR(500).
    Column names are derived from the DataFrame (i.e. from the CSV header).
    Schema is rebuilt on every run — no manual DDL maintenance required.
    """
    columns_ddl = ",\n    ".join(f"[{col}] NVARCHAR(500)" for col in df.columns)
    sql = f"CREATE TABLE [{TABLE_NAME}] (\n    {columns_ddl}\n);"
    log.info("Creating table [%s]...", TABLE_NAME)
    cursor.execute(sql)
    cursor.connection.commit()
    log.info("Table created.")


# ──────────────────────────────────────────────────────────────────────────────
# 6. Batched insert
# ──────────────────────────────────────────────────────────────────────────────
def insert_data(conn: pyodbc.Connection, df: pd.DataFrame) -> None:
    """
    Inserts all rows in batches of BATCH_SIZE, committing after each batch.

    Why batched instead of a single executemany:
    - Azure SQL Serverless terminates sessions idle for ~10 min mid-transaction
    - A single transaction for 300K+ rows exceeds that threshold reliably
    - Batching commits incrementally, keeping each transaction short
    - Progress is logged after every batch so the run is visibly active

    fast_executemany=True sends each batch as a single network round-trip,
    giving ~50-100x speedup over row-by-row inserts.
    """
    cols = ", ".join(f"[{c}]" for c in df.columns)
    placeholders = ", ".join("?" * len(df.columns))
    insert_sql = f"INSERT INTO [{TABLE_NAME}] ({cols}) VALUES ({placeholders})"

    # Convert DataFrame to list of tuples; map empty strings to None → SQL NULL
    rows = [
        tuple(None if v == "" else v for v in row)
        for row in df.itertuples(index=False, name=None)
    ]

    total = len(rows)
    log.info("Inserting %s rows in batches of %s...", total, BATCH_SIZE)
    t0 = time.time()

    for i in range(0, total, BATCH_SIZE):
        batch = rows[i : i + BATCH_SIZE]
        cursor = conn.cursor()
        cursor.fast_executemany = True
        cursor.executemany(insert_sql, batch)
        conn.commit()
        cursor.close()

        done = min(i + BATCH_SIZE, total)
        elapsed = time.time() - t0
        rate = done / elapsed if elapsed > 0 else 0
        log.info(
            "  %s / %s rows  (%.0f%%)  —  %.0f rows/s",
            done, total, done / total * 100, rate,
        )

    elapsed = time.time() - t0
    log.info("Insert completed in %.1f s  (%.0f rows/s avg)", elapsed, total / elapsed)


# ──────────────────────────────────────────────────────────────────────────────
# 7. Validation
# ──────────────────────────────────────────────────────────────────────────────
def validate(conn: pyodbc.Connection, expected_rows: int) -> None:
    """
    Post-load validation: row count check + sample of first 5 rows.
    Flags a MISMATCH if the DB count does not match the source DataFrame count.
    """
    cursor = conn.cursor()

    cursor.execute(f"SELECT COUNT(*) FROM [{TABLE_NAME}]")
    count = cursor.fetchone()[0]
    status = "OK" if count == expected_rows else "MISMATCH"
    log.info(
        "Row count: %s in DB  |  %s in source  |  [%s]",
        count, expected_rows, status,
    )

    log.info("Sample — first 5 rows:")
    cursor.execute(f"SELECT TOP 5 * FROM [{TABLE_NAME}]")
    headers = [d[0] for d in cursor.description]
    print("\n" + "  |  ".join(headers))
    print("-" * 120)
    for row in cursor.fetchall():
        print("  |  ".join("" if v is None else str(v) for v in row))
    print()

    cursor.close()


# ──────────────────────────────────────────────────────────────────────────────
# 8. Main
# ──────────────────────────────────────────────────────────────────────────────
def main() -> None:
    log.info("=== spi_nb_bronze_ipi — START ===")

    df          = read_csv(CSV_PATH)
    token_bytes = get_token_bytes()
    conn        = connect(token_bytes)

    try:
        cursor = conn.cursor()
        drop_table(cursor)     # drop first — ensures clean schema on every run
        create_table(cursor, df)
        cursor.close()

        insert_data(conn, df)
        validate(conn, expected_rows=len(df))

        log.info("=== spi_nb_bronze_ipi — SUCCESS ===")

    except Exception as exc:
        log.error("Load failed: %s", exc)
        conn.rollback()
        raise

    finally:
        conn.close()
        log.info("Connection closed.")


if __name__ == "__main__":
    main()
