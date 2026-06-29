"""
Sprint 2 (part I) - Construction MiTMA (Local Validation).
Generate a script to load data from an URL.
Get 4 files (XLS) and build a DataFrame.
Download the data in Parquet format to the working directory.
"""

import logging
from datetime import datetime, timezone
from pathlib import Path
import requests

import pandas as pd
import xlrd

# ────────────────────────────────────────────────────────────────────────────
# Configure Logging
# ────────────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("cons_xls_bronze_load")

# ────────────────────────────────────────────────────────────────────────────
# Configure environment variables
# ────────────────────────────────────────────────────────────────────────────
URL_BASE = "https://apps.fomento.gob.es/BoletinOnline/sedal/"
FILES = [
    {"file_id": "01401400.XLS", "agent": "estado",  "is_continuation": False},
    {"file_id": "01401600.XLS", "agent": "estado",  "is_continuation": True},
    {"file_id": "01402600.XLS", "agent": "entes",   "is_continuation": False},
    {"file_id": "01402800.XLS", "agent": "entes",   "is_continuation": True},
]
INPUT_FOLDER =  ("/Users/gastonbaloira/Projects/Portfolio/01_spi-indicators/"
               "02-prerequisites/cons-xls-bronze-load/input/")
OUTPUT_FOLDER =  ("/Users/gastonbaloira/Projects/Portfolio/01_spi-indicators/"
               "02-prerequisites/cons-xls-bronze-load/output/")

# ────────────────────────────────────────────────────────────────────────────
# Create function download_file
# ────────────────────────────────────────────────────────────────────────────
def download_file(file_id: str) -> Path:
    """
    Build the MiTMA URL with the constant and specified parameter.
    Download the input file to the working directory.
    Args:
        file_id (str): The value of the file_id parameter for the URL
    Returns:
        Path: Local path to the downloaded XLS file.    
    """
    xls_path = f"{URL_BASE}{file_id}"
    input_path_folder = Path(INPUT_FOLDER) / file_id
    log.info("Downloading: %s", file_id)
    response = requests.get(xls_path)
    response.raise_for_status() #if failed (e.g. 4xx), the process die.
    input_path_folder.write_bytes(response.content)
    log.info(
        "File downloaded: %s  |  Bytes: %s", 
        file_id, input_path_folder.stat().st_size,
    )
    return input_path_folder

# ────────────────────────────────────────────────────────────────────────────
# Create function cell_to_str
# ────────────────────────────────────────────────────────────────────────────
def cell_to_str(value) -> str:
    """Convert a xlrd cell to string. (Bronze layer)"""
    if isinstance(value, float):
        if value == int(value):
            return str(int(value))
        else:
            return str(value)
    else:
        return str(value)

# ────────────────────────────────────────────────────────────────────────────
# Create function parse_construction_xls
# ────────────────────────────────────────────────────────────────────────────
def parse_construction_xls(
        file_path: Path, 
        contracting_agent: str, 
        is_continuation: bool
) -> pd.DataFrame:
    """
    Read the XLS file from the input folder and return a DataFrame
    Args:
        file_path (Path): Path from the input folder.
        contracting_agent (str): Metadata from the constant FILES (agent) 
        is_continuation (bool): Metadata from the constant FILES (is_continuation)
    Returns:
        pd.DataFrame: A Dataframe with data and 4 lineage columns 
        (_ingestion_timestamp & _source_file, contracting_agent, is_continuation)
    """
    wb = xlrd.open_workbook(file_path)
    sh = wb.sheet_by_index(0)
    all_rows = []
    for r in range(sh.nrows):
        row = []                    
        for c in range(sh.ncols):     
            row.append(cell_to_str(sh.cell_value(r, c)))  
        all_rows.append(row)
    col_names = [f"col_{i:02d}" for i in range(1, sh.ncols + 1)]
    df = pd.DataFrame(all_rows, columns=col_names)
    df["contracting_agent"] = contracting_agent
    df["is_continuation"] = is_continuation
    df["_ingestion_timestamp"] = datetime.now(timezone.utc).isoformat()
    df["_source_file"] = file_path.name 
    log.info(
        "Parsed: %s  |  Rows: %s  |  Cols: %s",
        file_path.name, df.shape[0], df.shape[1],
    )
    return df

# ────────────────────────────────────────────────────────────────────────────
# Create function main to run the entire process
# ────────────────────────────────────────────────────────────────────────────
def main() -> None:
    """
    Main function that executes the entire process Data loading from MiTMA URL.
    """
    for f in FILES:
        path = download_file(f["file_id"])
        df = parse_construction_xls(path, f["agent"],f["is_continuation"])
        output_path = Path(OUTPUT_FOLDER) / f"{Path(f['file_id']).stem}.parquet"
        df.to_parquet(output_path, index=False)
        log.info("Stored: %s", output_path)

if __name__ == "__main__":
    main()