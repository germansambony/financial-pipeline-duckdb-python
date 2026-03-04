import pandas as pd
import duckdb
import os
import re
from typing import Dict, List
from datetime import datetime

class ExtractorLoad:
    def __init__(self, db_path: str = "innova.duckdb"):
        self.con = duckdb.connect(db_path)
        self.raw_data: Dict[str, pd.DataFrame] = {}
        self._init_metadata_table()
        print(f"Iniciando motor de extracción y carga incremental...")

    def _init_metadata_table(self):
        """Crea tabla de metadatos si no existe"""
        self.con.sql("""
            CREATE TABLE IF NOT EXISTS metadata_files (
                filename TEXT PRIMARY KEY,
                table_name TEXT,
                load_date TIMESTAMP,
                rows_loaded INTEGER
            )
        """)
        print("   📋 Tabla de metadatos inicializada")

    def _get_processed_files(self) -> set:
        """Obtiene archivos ya procesados"""
        result = self.con.sql("SELECT filename FROM metadata_files").fetchall()
        return {row[0] for row in result}

    def _get_existing_ids(self, table_name: str, id_column: str) -> set:
        """Obtiene IDs existentes en la tabla para evitar duplicados"""
        try:
            result = self.con.sql(f"SELECT {id_column} FROM {table_name}").fetchall()
            return {row[0] for row in result if row[0] is not None}
        except:
            return set()

    def _detect_date_pattern(self, filename: str) -> str:
        """Detecta si el archivo tiene patrón de fecha (transactions_2024-01.csv)"""
        match = re.search(r'_(\d{4}-\d{2})\.csv$', filename)
        return match.group(1) if match else None

    def _extract_data(self, data_folder: str = "data"):
        """Extrae datos de forma incremental"""
        print("\n [EXTRACT] Iniciando carga incremental...")
        
        files_config = {
            "transactions": {"file": "transactions", "id_col": "transaction_id"},
            "payments": {"file": "payments", "id_col": "payment_id"},
            "expenses": {"file": "expenses", "id_col": "expense_id"},
            "customers": {"file": "customers", "id_col": "customer_id"},
            "employees": {"file": "employees", "id_col": "employee_id"},
            "subscriptions": {"file": "subscriptions", "id_col": "subscription_id"}
        }

        processed_files = self._get_processed_files()

        for key, config in files_config.items():
            base_name = config["file"]
            id_column = config["id_col"]
            
            # Buscar archivos que coincidan con el patrón base
            all_files = os.listdir(data_folder)
            matching_files = [f for f in all_files if f.startswith(base_name) and f.endswith('.csv')]

            # Ordenar por fecha si tiene patrón (más antiguo primero)
            matching_files.sort(key=lambda x: self._detect_date_pattern(x) or '0000')

            for filename in matching_files:
                if filename in processed_files:
                    print(f"   ⏭️  Omitido (ya cargado): {filename}")
                    continue

                path = os.path.join(data_folder, filename)
                print(f"   📥 Procesando: {filename}")
                
                df = pd.read_csv(path)
                
                # Columnas de auditoría
                df['filename'] = filename
                df['load_date'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                # Normalizar nombres de columnas
                df.columns = [c.lower().strip().replace(" ", "_") for c in df.columns]

                # Detectar y eliminar duplicados vs datos existentes
                table_name = f"raw_{key}"
                existing_ids = self._get_existing_ids(table_name, id_column)
                
                if existing_ids:
                    id_col_normalized = id_column.lower()
                    if id_col_normalized in df.columns:
                        df_nuevos = df[~df[id_col_normalized].isin(existing_ids)]
                        duplicados = len(df) - len(df_nuevos)
                        if duplicados > 0:
                            print(f"      ⚠️  Duplicados omitidos: {duplicados}")
                        df = df_nuevos
                    else:
                        print(f"      ⚠️  Columna {id_column} no encontrada, cargando todos")
                else:
                    # Primera carga - crear tabla
                    pass

                if len(df) > 0:
                    # Cargar datos (append)
                    self.con.register("tmp_df", df)
                    
                    # Verificar si la tabla existe
                    table_exists = self.con.sql(f"SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '{table_name.upper()}'").fetchone()[0] > 0
                    
                    if table_exists:
                        self.con.sql(f"INSERT INTO {table_name} SELECT * FROM tmp_df")
                    else:
                        self.con.sql(f"CREATE TABLE {table_name} AS SELECT * FROM tmp_df")
                    
                    self.con.unregister("tmp_df")
                    
                    # Registrar en metadatos
                    self.con.sql("""
                        INSERT INTO metadata_files (filename, table_name, load_date, rows_loaded)
                        VALUES (?, ?, ?, ?)
                    """, params=[filename, table_name, datetime.now(), len(df)])
                    
                    print(f"      ✅ Cargado: {len(df)} filas nuevas -> {table_name}")
                else:
                    # Registrar como procesado aunque no tenga datos nuevos
                    self.con.sql("""
                        INSERT INTO metadata_files (filename, table_name, load_date, rows_loaded)
                        VALUES (?, ?, ?, 0)
                    """,  params=[filename, table_name, datetime.now()])
                    print(f"      ⏭️  Sin datos nuevos: 0 filas")

        print("\n [EXTRACT] Carga incremental completada")

    def show_tables(self):
        print("\n📊 Tablas en el Data Warehouse:")
        tables = self.con.sql("SHOW TABLES").fetchall()
        for table in tables:
            count = self.con.sql(f"SELECT COUNT(*) FROM {table[0]}").fetchone()[0]
            print(f"   - {table[0]}: {count} filas")
        
        print("\n📋 Archivos procesados:")
        files = self.con.sql("SELECT filename, table_name, rows_loaded, load_date FROM metadata_files ORDER BY load_date").fetchall()
        for f in files:
            print(f"   - {f[0]}: {f[2]} filas ({f[3]})")

if __name__ == "__main__":
    EL = ExtractorLoad(db_path="innova.duckdb")
    EL._extract_data("data")
    EL.show_tables()
