"""
Sprint 1 — REE API Rest (Validacion Local).
Generar Script para cargar datos desde la API de REE.
Leer los datos y construir un DataFrame.
Descargar los datos en formato Parquet en el directorio de trabajo.
"""

#Nativas (A-Z)
from datetime import datetime, timezone
import json
import logging
import time

#PIP (A-Z)
import pandas as pd
import requests

# ────────────────────────────────────────────────────────────────────────────
# #TODO_0. Configurar Logging
# ────────────────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("api_ree_bronze_load")

# ────────────────────────────────────────────────────────────────────────────
# #TODO_1. Configurar variables de entorno para la API
# ────────────────────────────────────────────────────────────────────────────

URL_BASE = "https://apidatos.ree.es"
ENDPOINT = "/en/datos/demanda/evolucion"
START_YEAR = 2014
END_YEAR = datetime.now().year
TIME_TRUNC = "month"
GEO_TRUNC = "electric_system"
GEO_ID_ESP = "8741"
GEO_LIMIT_ESP = "peninsular"
GEO_ID_MAD = "13"  
GEO_LIMIT_MAD = "ccaa"
GEO_ID_CAT = "9" 
GEO_LIMIT_CAT = "ccaa"
REGIONES = [
    {"nombre": "Espana", "id": GEO_ID_ESP, "limit": GEO_LIMIT_ESP},
    {"nombre": "Madrid", "id": GEO_ID_MAD, "limit": GEO_LIMIT_MAD},
    {"nombre": "Catalunya", "id": GEO_ID_CAT, "limit": GEO_LIMIT_CAT},
]

TIMEOUT = 30
BASE = 2
RETRIES = 3


OUTPUT = "ree_demanda.parquet"
PATH_OUTPUT = ("/Users/gastonbaloira/Projects/Portfolio/01_spi-indicators/"
               "02-prerequisites/ree-api-bronze-load/outputs/" + OUTPUT
)
# ────────────────────────────────────────────────────────────────────────────
# #TODO_2. Crear funcion build_request_url
# ────────────────────────────────────────────────────────────────────────────

def build_request_url(geo_limit: str, geo_ids: str) -> str:
    """
    Construye la URL de la API de REE con las constantes 
    y parámetros especificados.
    Args:
        geo_limit (str): El valor del parámetro geo_limit para la URL.
        geo_ids (str): El valor del parámetro geo_ids para la URL.    
    Returns:
        str: La URL completa para realizar la llamada a la API de REE."""
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
# #TODO_3. Crear funcion fetch_with_retry
# ────────────────────────────────────────────────────────────────────────────

def fetch_with_retry(url: str) -> dict:
    """Realiza una llamada a la API con reintentos en caso de fallo.
    Args:
        url (str): La URL de la API a la que se realizará la llamada.
    Returns:
        dict: La respuesta de la API en formato JSON si la llamada es exitosa.
    Raises:
        Exception: Si se alcanza el número máximo de reintentos sin éxito.
    """
    
    for attempt in range(1, RETRIES + 1):
        try:
            log.info(f"Intento {attempt} de {RETRIES}: Llamando a la API...")
            response = requests.get(url, timeout=TIMEOUT)
            status = response.status_code

            #Exito: 200-299
            if 200 <= status < 300:
                log.info("Llamada a la API exitosa.")
                return response.json()   
            
            #Errores temporales
            elif status in (429, 500, 502, 503, 504):
                delay = BASE ** attempt
                log.warning(f"Error temporal {status}. Reintentando...")
                time.sleep(delay)
            
            #Errores permanentes
            else:
                log.error(f"Error inesperado {status}. No se reintentará.")
                raise Exception(f"Error inesperado en la API: {status}")
        
        except (requests.exceptions.RequestException):
            if attempt < RETRIES:
                delay = BASE ** attempt
                log.info(f"Reintentando en {delay} segundos...")
                time.sleep(delay)
            
            else:
                log.error("Máximo de reintentos alcanzado. Fallo la llamada a la API.")
                raise
    
    raise RuntimeError("Error al llamar a la API después de varios intentos.")

# ────────────────────────────────────────────────────────────────────────────
# #TODO_4. Crear funcion parse_response
# ────────────────────────────────────────────────────────────────────────────

"""Funcion para parsear la respuesta de la API y convertirla en un DataFrame."""

# ────────────────────────────────────────────────────────────────────────────
# #TODO_5. Crear funcion build_dataframe
# ────────────────────────────────────────────────────────────────────────────

"""Funcion para construir el DataFrame a partir de los datos parseados."""

# ────────────────────────────────────────────────────────────────────────────
# #TODO_6. Crear main para ejecutar el proceso completo
# ────────────────────────────────────────────────────────────────────────────

#if __name__ == "__main__":
    # Construir la URL de la API
    # url = build_request_url(URL_BASE, ENDPOINT, GEO_1, GEO_2, GEO_3)
    
    # Realizar la llamada a la API con reintentos
    # response = fetch_with_retry(url, TIMEOUT, RETRIES, RETRY_DELAY)
    
    # Parsear la respuesta de la API
    # data = parse_response(response)
    
    # Construir el DataFrame
    # df = build_dataframe(data)
    
    # Guardar el DataFrame en formato Parquet
    # df.to_parquet(PATH_OUTPUT, index=False)
