import duckdb
import os
from extract import ExtractorLoad 

class FinancialPipeline:
    def __init__(self, db_path: str = "innova.duckdb"):
        self.db_path = db_path
        self.con = duckdb.connect(self.db_path)
        print(f"---  Iniciando Pipeline Financiero Innova ---")

    def run_sql_file(self, file_path):
        """Lee y ejecuta un archivo .sql"""
        if os.path.exists(file_path):
            with open(file_path, 'r', encoding='utf-8') as f:
                sql = f.read()
                self.con.execute(sql)
            print(f"✅ Ejecutado correctamente: {file_path}")
        else:
            print(f"⚠️ Error: No se encontró el archivo {file_path}")

    def execute_pipeline(self, data_folder: str):
        # 1. Extracción y Carga a RAW
        EL = ExtractorLoad(self.db_path)
        EL._extract_data(data_folder)

        # 2. Transformación a Capa SILVER 
        print("\n Iniciando Tranformacion y Limpieza (DWH) CAPA SILVER...")
        self.run_sql_file('sql/silver_transformations.sql')

        # 3. Creación de Capa GOLD 
        print("\n Generando métricas en Capa Gold...")
        self.run_sql_file('sql/gold_metrics.sql')

        # 4. Creación de VISTAS para BI
        print("\n Preparando vistas para Power BI...")
        self.run_sql_file('sql/bi_views.sql')
        
        self.con.sql('COPY GOLD.VW_DASHBOARD_MRR TO "Outputs_parquet/VW_DASHBOARD_MRR.parquet" (FORMAT PARQUET);')
        print("\n ✅ Cargado VW_DASHBOARD_MRR.parquet...")
        self.con.sql('COPY GOLD.VW_DASHBOARD_CAC TO "Outputs_parquet/VW_DASHBOARD_CAC.parquet" (FORMAT PARQUET);')
        print("\n ✅ Cargado /VW_DASHBOARD_CAC.parquet...")
        self.con.sql('COPY GOLD.VW_DASHBOARD_CASHFLOW TO "Outputs_parquet/VW_DASHBOARD_CASHFLOW.parquet" (FORMAT PARQUET);')
        print("\n ✅ Cargado VW_DASHBOARD_CASHFLOW.parquet...")

        print(f"\n Pipeline finalizado con éxito. Base de datos: {self.db_path}")

if __name__ == "__main__":
    
    pipeline = FinancialPipeline()
    pipeline.execute_pipeline(data_folder="data")