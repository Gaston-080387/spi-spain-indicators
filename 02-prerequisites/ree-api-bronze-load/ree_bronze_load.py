"""
Sprint 1 — REE API Rest (Local validation).
Generate a script to load data from the REE API.
Read the data and build a DataFrame.
Download the data in Parquet format to the working directory.
"""

from datetime import datetime, timezone
import json
import logging
import time

import pandas as pd
import requests

# ────────────────────────────────────────────────────────────────────────────
# Configure Logging
# ────────────────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("api_ree_bronze_load")

# ────────────────────────────────────────────────────────────────────────────
# Configure environment variables for the API
# ────────────────────────────────────────────────────────────────────────────

URL_BASE = "https://apidatos.ree.es"
ENDPOINT = "/en/datos/demanda/evolucion"
START_YEAR = 2014
END_YEAR = datetime.now().year
TIME_TRUNC = "month"
GEO_TRUNC = "electric_system"
REGIONS = [
    {"geo_name": "Espana", "geo_id": "8741", "geo_limit": "peninsular"},
    {"geo_name": "Madrid", "geo_id": "13", "geo_limit": "ccaa"},
    {"geo_name": "Catalunya", "geo_id": "9", "geo_limit": "ccaa"},
]

TIMEOUT = 30 
BASE = 2 
MAX_ATTEMPTS = 4 # attempts = 1 + 3 retries


OUTPUT = "ree_demanda.parquet"
PATH_OUTPUT = ("/Users/gastonbaloira/Projects/Portfolio/01_spi-indicators/"
               "02-prerequisites/ree-api-bronze-load/outputs/" + OUTPUT
)
# ────────────────────────────────────────────────────────────────────────────
# Create function build_request_url
# ────────────────────────────────────────────────────────────────────────────

def build_request_url(geo_limit: str, geo_ids: str) -> str:
    """
    Build the REE API URL with the constants and specified parameters.
    Args:
        geo_limit (str): The value of the geo_limit parameter for the URL.
        geo_ids (str): The value of the geo_ids parameter for the URL.   
    Returns:
        str: The complete URL to make the REE API call.
    """
    log.info("Building URL: ")
    url = (
        f"{URL_BASE}{ENDPOINT}?"
        f"start_date={START_YEAR}-01-01T00:00&"
        f"end_date={END_YEAR}-12-31T23:59&"
        f"time_trunc={TIME_TRUNC}&"
        f"geo_trunc={GEO_TRUNC}&"
        f"geo_limit={geo_limit}&"
        f"geo_ids={geo_ids}"
    )
    return url

# ────────────────────────────────────────────────────────────────────────────
# Create function fetch_with_retry
# ────────────────────────────────────────────────────────────────────────────

def fetch_with_retry(url: str) -> dict:
    """ 
    Makes an API call with retries on failure.
    Args:
        url (str): The URL of the API to which the call will be made.
    Returns:
        dict: The API response in JSON format if the call is successful.
    Raises:
        Exception: If the maximum number of unsuccessful retries is reached.
    """
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            log.info(f"Attempt {attempt} of {MAX_ATTEMPTS}: calling the API...")
            response = requests.get(url, timeout=TIMEOUT)
            status = response.status_code

            #Success: 200-299
            if 200 <= status < 300:
                log.info("Successful API call.")
                return response.json()   
            
            #Temporary errors
            elif status in (429, 500, 502, 503, 504):
                if attempt < MAX_ATTEMPTS:
                    delay = BASE ** attempt
                    log.warning(f"Temporary error {status}. Retrying...")
                    time.sleep(delay)
                else:
                    log.error(f"Maximum number of retries reached. Persistent temporary error: {status}.")
                    raise Exception(f"Persistent temporary error in the API: {status}")
            
            #Permanent errors
            else:
                log.error(f"Unexpected error {status}. No retry.")
                raise Exception(f"Unexpected error in the API: {status}")
        
        except (requests.exceptions.RequestException):
            if attempt < MAX_ATTEMPTS:
                delay = BASE ** attempt
                log.info(f"Retrying in {delay} seconds...")
                time.sleep(delay)
            
            else:
                log.error("Maximum retries reached. API call failed..")
                raise

    raise RuntimeError("Error calling the API after several attempts.")

# ────────────────────────────────────────────────────────────────────────────
# Create function parse_response
# ────────────────────────────────────────────────────────────────────────────

def parse_response(response: dict, geo_name: str) -> list:
    """
    Parse the API response and extract the relevant data.
    Args:
        response (dict): The API response in JSON format.
        geo_name (str): The name of the geolocation.
    Returns:
        list: A list of dictionaries with the parsed data.
    """
    log.info("Parsing API response..")
    rows = []
    for series in response["included"]:  
        series_type = series["type"] 
        for point in series["attributes"]["values"]:
            fila = {
                "serie_type": series_type,
                "geo_name": geo_name,
                "datetime": point.get("datetime"),
                "value": point.get("value"),
                "percentage": point.get("percentage")
            }
            rows.append(fila)
    return rows

# ────────────────────────────────────────────────────────────────────────────
# Create function build_dataframe
# ────────────────────────────────────────────────────────────────────────────

def build_dataframe(data: list) -> pd.DataFrame:
    """
    Builds a pandas DataFrame from a list of dictionaries.
    Args:
        data (list): A list of dictionaries with the parsed data.
    Returns:
        pd.DataFrame: A DataFrame with the data.
    """
    log.info("Building DataFrame..")
    df = pd.DataFrame(data)
    df["_ingestion_timestamp"] = datetime.now(timezone.utc).isoformat()
    df["_source_api"] = ENDPOINT
    df = df.astype(str) # Converted to String by the principle of bronze layer 
    return df

# ────────────────────────────────────────────────────────────────────────────
# Create main to run the entire process
# ────────────────────────────────────────────────────────────────────────────

def main() -> None:
    """
    Main function that executes the entire process Data loading from the REE API.
    """
    all_data = []
    for region in REGIONS:
        geo_name = region["geo_name"]
        geo_id = region["geo_id"]
        geo_limit = region["geo_limit"]

        url = build_request_url(geo_limit, geo_id)
        log.info(f"Processing region: {geo_name}")

        response = fetch_with_retry(url)
        parsed_data = parse_response(response, geo_name)
        all_data.extend(parsed_data)

    df = build_dataframe(all_data)
    df.to_parquet(PATH_OUTPUT, index=False)
    log.info(f"Data stored in {PATH_OUTPUT}")
    
if __name__ == "__main__":
    main()