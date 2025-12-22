import pandas as pd
import duckdb
import os
from typing import Dict
from datetime import datetime  # Importado para la fecha de carga

# --- EXTRACCION Y CARGA DE DATOS (EL)---
# CARGA DE DATOS EN DUCKDB RETORNANDO ARCHIVO innova.duckdb
# SE SUBEN TODOS LOS DATOS CRUDOS (RAW)

class Extractor_load:
    def __init__(self, db_path: str = "innova.duckdb"):  #RUTA DONDE GUARDARA SU BD EN ESTE CASO EN LA MISMA CARPETA CONTENEDORA DEL SCRIPT
        # Inicializa la base de datos (en memoria Local)
        self.con = duckdb.connect(db_path)
        self.raw_data: Dict[str, pd.DataFrame] = {}
        print(f" Iniciando motor extraccion y carga...")
	
    def extract_data(self, data_folder: str = "data"):
        # Lee los CSV y los carga en DuckDB
        print("\n [EXTRACT] Leyendo archivos fuente...")
        files = {
            "transactions": "transactions.csv",
            "payments": "payments.csv",
            "expenses": "expenses.csv",
            "customers": "customers.csv",
            "employees": "employees.csv",
            "subscriptions": "subscriptions.csv"
        }

        for key, filename in files.items():
            path = os.path.join(data_folder, filename)
            print (path)
            if os.path.exists(path):
                df = pd.read_csv(path)
                
                # ---COLUMNAS DE PARA AUDITORIA Y SOPORTE---
                df['filename'] = filename
                df['load_date'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                # Limpiar nombres de columnas (minusculas, sin espacios y separar palabras por _ (Convension))
                df.columns = [c.lower().strip().replace(" ", "_") for c in df.columns]
                
                self.raw_data[key] = df
                
                # Registro en DuckDB
               
                self.con.register("tmp_df", df)
                self.con.sql(f"CREATE OR REPLACE TABLE raw_{key} AS SELECT * FROM tmp_df")
                self.con.unregister("tmp_df") 
                print(f"   ✅ Cargado: {filename} -> Tabla: 'raw_{key}' ({len(df)} filas)")
            else:
                print(f"   ⚠️ ALERTA: No se encontró {filename} en la carpeta '{data_folder}'")
        return self.raw_data

    def show_tables(self):
        # Muestra qué tablas existen en la BD - PRUEBAS
        print("\n Tablas en el Data Warehouse:")
        print(self.con.sql("SHOW TABLES"))
        #print(self.con.sql("SELECT * FROM raw_customers LIMIT 10"))

if __name__ == "__main__":
    EL = Extractor_load(db_path="innova.duckdb")  #RUTA DONDE GUARDARA SU BD EN ESTE CASO EN LA MISMA CARPETA CONTENEDORA DEL SCRIPT
    TABLES = EL.extract_data("data")  # Carga los CSV RUTA DONDE ESTA LA CARPETA DATA
    #transactions = TABLES['transactions']
    #print(transactions.head())
    #EL.raw_data.keys()
    EL.show_tables()     