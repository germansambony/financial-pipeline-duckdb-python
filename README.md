

---
# 📊 Data Warehouse Financiero: El Backend de la Inteligencia SaaS

Este proyecto implementa un Pipeline de Datos integral (End-to-End) para una empresa SaaS. La solución transforma datos transaccionales crudos en una arquitectura de **Data Warehouse moderna**, utilizando **Arquitectura de Medallion**, un proceso **ELT** y un modelo dimensional basado en la metodología de **Ralph Kimball (Star Schema)** para potenciar la toma de decisiones estratégicas.

---

## 🏗️ 1. Arquitectura de la Solución

Se ha seleccionado una arquitectura basada en **DuckDB** por su alto rendimiento en procesamiento analítico (OLAP) y su versatilidad para ser orquestado mediante Python en entornos locales o de nube.

### Capas de Datos (Medallion Architecture):
1.  **Capa RAW (Bronce):** Ingesta inmutable de archivos CSV. Los datos se extraen y cargan (EL) preservando los originales e incluyendo metadatos de auditoría (`filename`, `load_date`).
2.  **Capa SILVER (Plata):** Fase de limpieza y estandarización. Se eliminan duplicados y se implementa lógica de **SCD (Slowly Changing Dimensions)**:
    *   **SCD Tipo 2:** Aplicado a la geografía (`country`) para mantener la trazabilidad histórica de los movimientos de los clientes.
    *   **SCD Tipo 1:** Para atributos que no requieren historial.
    *   Se manejan inconsistencias de negocio (ej. validación de rangos de fechas en suscripciones).
3.  **Capa GOLD (Oro):** Capa de consumo final. Aquí reside el **Modelo en Estrella**, con tablas de hechos y dimensiones optimizadas para herramientas de BI (Power BI) y cálculos de métricas complejas (MRR, CAC, FCF).

---

## 📉 2. Modelo Dimensional (Kimball)

El modelo está diseñado para separar los hechos (métricas cuantitativas) de las dimensiones (contexto), facilitando el filtrado y la agregación:

### Tablas de Hechos (Facts):
-   **`GOLD.FACT_MRR_MONTHLY`**: Grano mensual por suscripción activa. Utiliza lógica recursiva para el llenado de periodos (*gap filling*), permitiendo analizar el crecimiento del ingreso recurrente.
-   **`GOLD.FACT_CASHFLOW`**: Consolidado transaccional de entradas (Pagos) y salidas (Gastos) para el cálculo de flujo de caja neto.

### Tablas de Dimensiones (Dims):
-   **`GOLD.DIM_DATE`**: Dimensión de tiempo generada dinámicamente para soportar *Time Intelligence*.
-   **`SILVER.S_CUSTOMERS` / `S_EMPLOYEES`**: Dimensiones de entidades con soporte de historial.
-   **`SILVER.S_EXPENSES`**: Actúa como dimensión contextual para los gastos, permitiendo categorizar proveedores y tipos de egresos. 
    *Nota:* En una fase productiva, estas tablas se normalizarían en `DIM_PROVIDER`, `DIM_CATEGORY`,`DIM_CUSTOMERS` y `DIM_EMPLOYEES` dentro de la capa GOLD para cumplir estrictamente con el estándar Kimball y que sea segun las necesidades del cliente en los dash y la interaccion del usuario analista.
 

##  3. Pipeline ELT y Orquestación

El flujo de datos es gobernado por un orquestador central en Python (`main_orchestrator.py`):

1.  **Extracción (`extract.py`):** Lee archivos CSV, normaliza nombres de columnas y registra las tablas en el motor DuckDB. Codigo centralizado en escalabilidad y validacion de archivos.
2.  **Transformación (`silver_transformations.sql`):** Aplica lógica de limpieza y transformacion. Se destaca la creación de la tabla `S_TABLA_ERROR` para identificar registros de suscripciones descartados por errores de lógica de fechas y duplicados.
3.  **Modelado (`gold_metrics.sql`):** Implementa las métricas financieras core y agrupaciones para eficiencia en consultas
4.  **Exposición (`bi_views.sql` y `main_orchestrator`):** Crea vistas optimizadas para consumo externo, el orquestador realiza el pipeline  y exporta archivos **.Parquet**, asegurando un rendimiento superior y menor peso que el formato CSV. Esto para ser leido desde Power Bi

---

##  4. Consultas clave de Negocio (Resultados 2024)

Basado en el modelo implementado , en `Respuestas_prueba.sql`, se han respondido las siguientes métricas clave:

| Pregunta | Resultado |
| :--- | :--- |
| **MRR Total Agosto 2024** | $56,600 |
| **Clientes Nuevos Q1 2024** | 235 |
| **Gastos Marketing H1 2024** | $736,200 |
| **Free Cash Flow (FCF) Diciembre 2024** | -$533,861 |
| **País con mayor ingreso total** | United States ($268,366) |
| **CAC Promedio Anual** | $1,499.35 |

---

## 5. Dashboard Ejecutivo - Innova Finance

El modelo Gold se conecta a un tablero en Power BI, proporcionando visibilidad en tiempo real. El archivo `DASHBOARD BI INNOVA.pbix` contiene el tablero.

![Dashboard Innova Finance](INNOVA_BI_DASH.png) 

**Visualizaciones incluidas:**
-   **Evolución del MRR:** Tendencia mensual segmentada por plan.
-   **Análisis de CAC:** Comparativa de eficiencia por canal de adquisición.
-   **Cash Flow:** Visualización de Inflows vs. Outflows.

---

## 6. Escalabilidad y Futuro 

Para que esta sección demuestre un nivel **Senior**, debemos dejar de hablar de "hacer un join" y pasar a hablar de **"Arquitectura de Referencia"**. Un Senior no solo resuelve el problema técnico, sino que piensa en la auditoría, la precisión de los datos y la facilidad de mantenimiento.

Aquí tienes una versión expandida y robustecida para tu archivo `README.md`:

---


#### 🌍 Escalabilidad Global y Soporte Multimoneda
Para transformar este pipeline en una solución de alcance global que soporte la expansión de **Innova**, se proponen las siguientes mejoras estructurales:

*   **Módulo de Conversión FX (Foreign Exchange):**
    *   **Normalización ISO:** Implementar el estándar **ISO 4217** para códigos de moneda (USD, MXN, COP, etc.) asegurando la integridad de los datos entre diferentes sistemas fuente.
    *   **Capa de Referencia:** Integración de una tabla `DIM_EXCHANGE_RATES` con granularidad diaria. En la **Capa Silver**, se realizaría un *Temporal Join* entre las transacciones y las tasas de cambio basadas en la fecha del evento.
    *   **Doble Contabilidad (Reporting vs. Functional):** El modelo Gold evolucionará para almacenar cada métrica en dos dimensiones: `amount_local` (para auditoría fiscal local) y `amount_reporting_usd` (para consolidación financiera global), permitiendo análisis de impacto por volatilidad cambiaria.

*   **Arquitectura Metadata-Driven para Nuevos Países:**
    *   **Localización Dinámica:** En lugar de hardcodear lógicas por país, se propone un esquema basado en configuración (YAML/JSON). Esto permitiría añadir un nuevo país (ej. Colombia o Brasil) simplemente registrando sus reglas de impuestos y periodos fiscales en la tabla de metadatos, sin modificar el código core del pipeline.
    *   **Estrategia de Particionamiento:** Para mantener el rendimiento de **DuckDB** ante el crecimiento masivo de datos, se implementará un particionamiento físico de los archivos **Parquet** por `year`, `month` y `country`. Esto permite que las consultas de Power BI solo escaneen los datos necesarios (*Partition Pruning*).

*   **Llaves Subrogadas y Unicidad Global:**
    *   Implementación de **Surrogate Keys** mediante funciones HASH (ej. `MD5` o `SHA256`) combinando el ID natural y el código de país. Esto garantiza que un `Client_001` en México no colisione con un `Client_001` en EE.UU. si los sistemas operacionales son independientes.

---



### Automatización y DevOps:
-   **dbt (data build tool):** Para una implementación productiva, propongo migrar las transformaciones SQL a dbt (data build tool) para obtener las siguientes ventajas:
Modelado Incremental (Append): Optimización del pipeline cambiando la materialización de table (overwrite) a incremental. Esto permite procesar solo las nuevas transacciones diarias, reduciendo drásticamente el consumo de cómputo y memoria. Ademas datos mas precisos para posibles SCD tipo 1 guardados en el esquema de RAW, con la carga y compiliacion exacata de cada consideracion de duplicado en el historial.
Gestión de Infraestructura: Configuración de perfiles de conexión para asignar modelos pesados (Capa Gold) a clusters de alta memoria y modelos ligeros a clusters económicos.
Data Quality & Alarms: Implementación de tests de unicidad y consistencia financiera con alertas automáticas ante anomalías en métricas críticas como el MRR.
Seguridad: Aplicación de políticas de encriptación a nivel de columna para datos sensibles de nómina y clientes, asegurando el cumplimiento de normativas de privacidad.

### IA y Machine Learning:
-   **Forecast Financiero:** Utilizar modelos de series temporales (Prophet o ARIMA) sobre la tabla `FACT_MRR_MONTHLY` para predecir ingresos futuros.
-   **Clasificación Inteligente:** Implementar técnicas de Procesamiento de Lenguaje Natural (NLP) para leer descripciones de los proveedores en los archivos de gastos. Esto permitiría clasificar automáticamente un gasto como "Infraestructura" o "Marketing" aunque el nombre del proveedor sea ambiguo o nuevo, reduciendo el error humano y el trabajo manual de limpieza en la capa Silver.


---

## 7. Configuración del Proyecto

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

Para explorar la Base de datos generada `innova.duckdb`, se recomienda utilizar:
* **DBeaver:** Conector nativo de DuckDB disponible.
* **DataGrip:** Ideal para análisis avanzado de SQL.

---

## 8 🚀 Roadmap de Evolución (Hacia un Entorno Productivo)
Este proyecto fue concebido como un MVP (Producto Mínimo Viable) robusto y escalable. Para elevar esta arquitectura a un estándar de producción empresarial ("Production-Ready"), se proponen los siguientes hitos técnicos:
Contenedorización e Inmutabilidad: Implementar Docker para encapsular el entorno de ejecución, garantizando que el pipeline sea reproducible y agnóstico a la infraestructura. Esto facilitaría su despliegue en orquestadores corporativos como Apache Airflow, Prefect o clusters de Kubernetes.
Data Observability & Quality: Integrar Great Expectations para establecer contratos de datos y reglas de validación automática. El objetivo es implementar un "Circuit Breaker" que detenga el pipeline ante la detección de duplicados, nulos en llaves primarias o desviaciones estadísticas anómalas en métricas críticas como el MRR.
Arquitectura Event-Driven & Carga Incremental: Evolucionar la ingesta hacia un sistema de State Management. Mediante el uso de Cloud Triggers (S3 Triggers o Event Grid), el pipeline procesaría únicamente los deltas de datos (archivos nuevos), optimizando drásticamente los costos de cómputo y el tiempo de respuesta.
Infraestructura como Código (IaC): Definir la provisión de todos los recursos (almacenamiento, permisos y motor de base de datos) mediante Terraform o AWS CDK, permitiendo despliegues consistentes, versionados y automatizados en entornos de Desarrollo, Staging y Producción.

**Autor:** [German Camilo Sambony Ledezma] - Data Engineer 
**Contacto:** [camilosambony@gmail.com/[LinkedIn](https://www.linkedin.com/in/germansambony-dataengineer/)]
