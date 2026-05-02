# IPI Source — Azure SQL Database Load

One-time prerequisite script that loads the IPI CSV from INE (Instituto Nacional de
Estadística de España) into Azure SQL Database. Simulates a real-world scenario where
source data is already available in a transactional database, and the Fabric pipeline
reads from there.

## Why a Python script and not a Fabric pipeline?

The Fabric pipeline (Phase 5) reads IPI data **from Azure SQL**, not from the original
CSV. To populate Azure SQL with realistic data, this script performs the initial load —
exactly as a real client organization would have done historically using SSIS, Azure
Data Factory, or a custom loader.

## Prerequisites

- Azure SQL Database provisioned (`spi_staging` on `spi-sqlserver-gb.database.windows.net`)
- Microsoft Entra-only authentication enabled on the server
- Your Entra ID user added as Server admin
- ODBC Driver 18 installed locally (Mac M3):

```bash
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew install msodbcsql18
odbcinst -q -d   # validate registration
```

- Azure CLI installed and authenticated:

```bash
brew install azure-cli
az login --tenant gastonbaloiraoutlook.onmicrosoft.com
```

## Run

```bash
python ipi_bronze_load.py
```

## What the script does

1. Reads INE IPI CSV (`02-IPI-60272.csv`) — semicolon delimiter, UTF-8 with BOM
2. Acquires Microsoft Entra ID token via `DefaultAzureCredential` (uses cached `az login`)
3. Connects to Azure SQL with auto-pause retry handling (error 40613)
4. Drops and recreates `staging_ipi_raw` table (idempotent full reload)
5. Bulk inserts ~309K rows in batches of 5,000 with `fast_executemany=True`
6. Validates row count and shows first 5 rows

## Performance

| Operation | Duration |
|-----------|----------|
| CSV read (309K rows) | ~2 seconds |
| Token acquisition | ~1 second |
| Connection (cold start, DB paused) | up to ~60 seconds |
| Connection (warm) | ~1 second |
| Bulk insert (309K rows) | ~30 seconds |
| **Total run (warm DB)** | **~35 seconds** |

## Bronze pattern compliance

- All columns stored as `NVARCHAR(500)` (no type enforcement)
- Empty strings preserved as SQL NULL (not empty strings)
- Metadata columns added: `_ingestion_timestamp`, `_source_file`
- No transformations, no filtering — raw ingestion only

## Known gotchas

- **HYT00 timeout error:** caused by missing `Encrypt=yes;TrustServerCertificate=no` in
  the connection string. The ODBC driver fails silently in the Entra ID handshake without
  these parameters.
- **First connection ~30-60s:** Azure SQL Serverless auto-pauses after ~1h inactivity.
  The first query triggers resume; subsequent queries are fast.
- **Token packing:** Entra ID tokens must be packed in a specific binary format
  (4-byte length prefix + UTF-16-LE) and passed via `attrs_before={1256: token_bytes}`.

## Author

Gaston Baloira | May 2026
