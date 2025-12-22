

---

# 📊 Innova Financial Data Warehouse: El Backend de la Inteligencia SaaS

Este proyecto implementa un Pipeline de Datos integral para **Innova**, una empresa SaaS líder en soluciones financieras. La solución transforma datos transaccionales crudos en una arquitectura de **Data Warehouse moderna**, utilizando una arquitectura de medallas (Medallion Architecture) y un modelo dimensional en estrella (Star Schema) para potenciar la toma de decisiones estratégicas.

---

## 🏗️ 1. Arquitectura de la Solución

Se ha seleccionado una arquitectura basada en **DuckDB** por su alto rendimiento en procesamiento analítico (OLAP) y su facilidad de orquestación mediante Python.

### Capas de Datos (Medallion Architecture):
1.  **Capa RAW (Bronce):** Ingesta directa de archivos CSV. Los datos se cargan "as-is" pero con metadatos de auditoría (`filename`, `load_date`).
2.  **Capa SILVER (Plata):** Limpieza y estandarización. Se eliminan duplicados mediante lógica de ventanas (`QUALIFY`), se formatean tipos de datos y se manejan inconsistencias de negocio (ej. fechas de fin de suscripción inválidas).
3.  **Capa GOLD (Oro):** Modelado analítico. Aquí reside el **Modelo en Estrella**, optimizado para consultas de BI y métricas complejas como MRR, CAC y FCF.

---

## 📉 2. Modelo Dimensional Propuesto

Para satisfacer las necesidades del equipo financiero, el modelo Gold se estructura de la siguiente manera:

### Tablas de Hechos (Facts):
-   **`GOLD.FACT_MRR_MONTHLY`**: Grano mensual por suscripción activa. Utiliza lógica recursiva para "llenar los huecos" de meses entre la fecha de inicio y fin, permitiendo ver la evolución del ingreso recurrente.
-   **`GOLD.FACT_CASHFLOW`**: Grano transaccional. Consolida entradas (Pagos) y salidas (Gastos) en una única estructura para calcular el flujo de caja neto.

### Tablas de Dimensiones (Dims):
-   **`GOLD.DIM_DATE`**: Dimensión de tiempo generada dinámicamente para facilitar el *time-intelligence* en Power BI.
-   **`SILVER.S_CUSTOMERS`**: Atributos del cliente (segmento, país, canal).
-   **`SILVER.S_EMPLOYEES`**: Datos de nómina y geografía.

---

## ⚙️ 3. Pipeline ETL y Orquestación

El flujo de datos es gobernado por un orquestador central en Python (`main_orchestrator.py`):

1.  **Extracción (`extract.py`):** Lee archivos CSV, normaliza nombres de columnas (snake_case) y registra las tablas en el motor DuckDB.
2.  **Transformación (`silver_transformations.sql`):** Aplica lógica de limpieza. Se destaca la creación de la tabla `S_TABLA_ERROR` para identificar registros de suscripciones descartados por errores de lógica de fechas.
3.  **Modelado (`gold_metrics.sql`):** Implementa las métricas financieras core.
4.  **Exposición (`bi_views.sql`):** Crea vistas optimizadas para consumo externo y exporta archivos **Parquet**, asegurando un rendimiento superior y menor peso que el formato CSV.

---

## 🧪 4. Consultas de Negocio (Resultados 2024)

Basado en el modelo implementado, se han respondido las siguientes métricas clave:

| Pregunta | Resultado |
| :--- | :--- |
| **MRR Total Agosto 2024** | $56,600 |
| **Clientes Nuevos Q1 2024** | 235 |
| **Gastos Marketing H1 2024** | $736,200 |
| **Free Cash Flow (FCF) Diciembre 2024** | -$533,861 |
| **País con mayor ingreso total** | United States ($268,366) |
| **CAC Promedio Anual** | $1,499.35 |

---

## 📊 5. Dashboard Ejecutivo - Innova Finance

El modelo Gold se conecta a un tablero en Power BI, proporcionando visibilidad en tiempo real.

![Dashboard Innova Finance](ruta_a_tu_imagen/dashboard.png) *(Nota: Asegúrate de guardar la imagen en tu repositorio)*

**Visualizaciones incluidas:**
-   **Evolución del MRR:** Tendencia mensual segmentada por plan.
-   **Análisis de CAC:** Comparativa de eficiencia por canal de adquisición.
-   **Cash Flow Bridge:** Visualización de Inflows vs. Outflows.
-   **Segmentación Geográfica:** Desempeño por país.

---

## 🚀 6. Escalabilidad y Futuro (Bonus)

### Escalabilidad a Nuevos Países y Monedas:
-   **Multimoneda:** Para escalar a otras divisas, se propone añadir una tabla de hechos `DIM_EXCHANGE_RATES` (tasas de cambio diarias). Las tablas Gold incluirían columnas `amount_local` y `amount_usd`, realizando la conversión dinámicamente mediante un `JOIN` con la tabla de tasas.
-   **Nuevos Países:** La estructura actual es agnóstica al país. Solo requiere añadir el nuevo valor en la fuente y el modelo lo absorberá automáticamente.

### Automatización y DevOps:
-   **dbt (data build tool):** Se recomienda migrar los scripts SQL a dbt para manejar linaje de datos, pruebas automáticas de integridad y documentación integrada.
-   **Airflow/Prefect:** Para una orquestación robusta con reintentos, alertas y programación de tareas (CRON).

### IA y Machine Learning:
-   **Forecast Financiero:** Utilizar modelos de series temporales (Prophet o ARIMA) sobre la tabla `FACT_MRR_MONTHLY` para predecir ingresos futuros.
-   **Clasificación Inteligente:** Usar NLP para categorizar automáticamente gastos basados en el nombre del proveedor en caso de categorías ambiguas en el CSV.

---

## 🛠️ 7. Configuración del Proyecto

### Requisitos Previos:
-   Python 3.8+
-   PIP (Gestor de paquetes)

### Instalación:
1.  Clona el repositorio.
2.  Instala las dependencias necesarias:
    ```bash
    pip install -r requirements.txt
    ```

### Ejecución del Pipeline:
Para ejecutar todo el proceso (desde extracción hasta la generación de archivos para Power BI), corre:
```bash
python main_orchestrator.py
```
*Esto generará el archivo `innova.duckdb` y los archivos `.parquet` en la carpeta `Outputs_parquet/`.*

---

**Autor:** [Tu Nombre] - Data Engineer Principal
**Contacto:** [Tu Email/LinkedIn]
