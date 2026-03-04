# AGENTS.md - Pipeline Financiero DuckDB

## Descripción del Proyecto

Este es un **Pipeline de Datos End-to-End** para una empresa SaaS llamada "Innova" que transforma datos transaccionales crudos en un **Data Warehouse** moderno utilizando:
- **DuckDB** como motor OLAP
- **Arquitectura Medallion** (Bronce → Plata → Oro)
- **Modelado Dimensional de Kimball** (Star Schema)
- **Orquestación en Python** para el proceso ELT
- **Exportaciones Parquet** para consumo en Power BI

## Estructura del Repositorio

```
├── main_orchestrator.py          # Orquestador principal del pipeline
├── extract.py                   # Extracción CSV y carga a capa RAW
├── innova.duckdb                # Archivo de base de datos DuckDB (generado)
├── requirements.txt             # Dependencias de Python
├── README.md                    # Documentación del proyecto
├── sql/
│   ├── silver_transformations.sql  # Limpieza, deduplicación, SCD
│   ├── gold_metrics.sql             # Tablas de hechos y métricas
│   ├── bi_views.sql                 # Vistas para Power BI
│   └── Ejem_consult_empresariales.sql  # Ejemplos de consultas de negocio
├── data/                        # Archivos CSV fuente
│   ├── customers.csv            # Datos de clientes (~1000 registros)
│   ├── subscriptions.csv        # Datos de suscripciones (~2000 registros)
│   ├── transactions.csv         # Transacciones de ventas
│   ├── payments.csv            # Registros de pagos
│   ├── expenses.csv            # Gastos operativos
│   └── employees.csv           # Datos de empleados
├── Outputs_parquet/             # Archivos Parquet generados
│   ├── VW_DASHBOARD_MRR.parquet
│   ├── VW_DASHBOARD_CAC.parquet
│   └── VW_DASHBOARD_CASHFLOW.parquet
└── DASHBOARD BI INNOVA.pbix     # Dashboard de Power BI
```

## Arquitectura (Medallion)

### Capa Bronze (RAW)
- Ingesta de CSV crudos con metadatos (`filename`, `load_date`)
- Datos fuente inmutables
- Tablas: `raw_customers`, `raw_subscriptions`, `raw_transactions`, `raw_payments`, `raw_expenses`, `raw_employees`

### Capa Plata (Silver)
- **Deduplicación** usando `QUALIFY ROW_NUMBER()` para mantener los registros más recientes
- **SCD Tipo 2** para geografía (`country` en clientes)
- **SCD Tipo 1** para atributos sin historial
- **Manejo de errores** con tabla `S_TABLA_ERROR` para suscripciones inválidas
- Tablas: `S_CUSTOMERS`, `S_EMPLOYEES`, `S_TRANSACTIONS`, `S_PAYMENTS`, `S_EXPENSES`, `S_SUBSCRIPTIONS`, `S_TABLA_ERROR`

### Capa Oro (Gold)
- **Star Schema** con tablas de hechos y dimensiones
- **FACT_MRR_MONTHLY**: Ingresos recurrentes mensuales con llenado de huecos (recursive CTE)
- **FACT_CASHFLOW**: Entradas/salidas de efectivo
- **DIM_DATE**: Dimensión de tiempo (2023-2025)
- Vistas: `VW_DASHBOARD_MRR`, `VW_DASHBOARD_CAC`, `VW_DASHBOARD_CASHFLOW`

## Modelo de Datos

### Esquema de Datos Fuente (CSV)

| Archivo | Columnas |
|---------|----------|
| customers.csv | customer_id, country, acquisition_channel, segment, registration_date |
| subscriptions.csv | subscription_id, customer_id, plan, start_date, end_date, status, monthly_price_usd |
| transactions.csv | transaction_id, customer_id, product_id, date, country, quantity, unit_price_usd, total_usd |
| payments.csv | payment_id, transaction_id, payment_date, method, amount_usd |
| expenses.csv | expense_id, date, provider, category, country, amount_usd |
| employees.csv | employee_id, area, salary_usd, country, hire_date |

### Esquema de Capa Silver

| Tabla | Columnas Clave | Descripción |
|-------|----------------|-------------|
| S_CUSTOMERS | S_CUSTOMER_ID, S_COUNTRY, S_ACQUISITION_CHANNEL, S_SEGMENT, S_REGISTRATION_TIMESTAMP, IS_CURRENT | Clientes deduplicados con SCD Tipo 2 para país |
| S_EMPLOYEES | S_EMPLOYEE_ID, S_AREA, S_SALARY_USD, S_COUNTRY, S_HIRE_DATE | Empleados deduplicados |
| S_TRANSACTIONS | S_TRANSACTION_ID, S_CUSTOMER_ID, S_PRODUCT_ID, S_TRANSACTION_DATE, S_COUNTRY, S_QUANTITY, S_UNIT_PRICE_USD, S_TOTAL_USD | Transacciones limpiadas |
| S_PAYMENTS | S_PAYMENT_ID, S_TRANSACTION_ID, S_PAYMENT_DATE, S_PAYMENT_METHOD, S_AMOUNT_USD | Pagos limpiados |
| S_EXPENSES | S_EXPENSE_ID, S_EXPENSE_DATE, S_PROVIDER, S_CATEGORY, S_COUNTRY, S_AMOUNT_USD | Gastos limpiados |
| S_SUBSCRIPTIONS | S_SUBSCRIPTION_ID, S_CUSTOMER_ID, S_PLAN_TYPE, S_START_DATE, S_END_DATE, S_STATUS, S_MONTHLY_PRICE, IS_ACTIVE_TODAY | Suscripciones validadas |
| S_TABLA_ERROR | subscription_id, customer_id, start_date, end_date, status, filename, MOTIVO_EXCLUSION | Registros de suscripciones rechazados |

### Esquema de Capa Gold

| Tabla | Columnas Clave | Granularidad |
|-------|----------------|--------------|
| DIM_DATE | DATE_ID, YEAR, MONTH, QUARTER, YEAR_MONTH | Una fila por día calendario |
| FACT_MRR_MONTHLY | G_SUBSCRIPTION_ID, G_CUSTOMER_ID, G_PLAN_TYPE, G_MONTHLY_PRICE, G_MONTHS_ADD, G_STATUS, G_YEAR_MONTH | Una fila por suscripción activa por mes |
| FACT_CASHFLOW | G_TRANSACTION_REF, G_FLOW_DATE, G_FLOW_TYPE (INFLOW/OUTFLOW), G_CATEGORY, G_NET_AMOUNT_USD | Una fila por movimiento financiero |
| VW_DASHBOARD_MRR | DATE_MONTH, COUNTRY, PLAN, TOTAL_MRR | MRR agregado por mes/país/plan |
| VW_DASHBOARD_CAC | YEAR, MONTH, QUARTER, YEAR_MONTH, MONTH_DATE, COUNTRY, TOTAL_MARKETING_COST, NEW_CLIENTS, ACQUISITION_CHANNEL, CAC | Métricas de CAC por canal |
| VW_DASHBOARD_CASHFLOW | YEAR, MONTH, QUARTER, YEAR_MONTH, DATE, G_FLOW_TYPE, G_CATEGORY, AMOUNT, AGRUPADO | Agregación de flujo de caja |

## Flujo del Pipeline

### 1. extract.py (EL - Extracción y Carga)
```
- Leer archivos CSV de la carpeta data/
- Agregar columnas de auditoría: filename, load_date
- Normalizar nombres de columnas (minúsculas, snake_case)
- Crear tablas RAW en DuckDB
```

### 2. silver_transformations.sql (T - Transformación)
```
- Deduplicar usando QUALIFY ROW_NUMBER()
- Conversión de tipos (TRY_CAST, CAST)
- Lógica SCD Tipo 2 para geografía de clientes
- Validación de datos (end_date >= start_date)
- Crear tabla de errores para registros rechazados
```

### 3. gold_metrics.sql (Modelado)
```
- Generar DIM_DATE (recursive CTE: 2023-2025)
- Crear FACT_MRR_MONTHLY con gap-filling (recursive CTE)
- Crear FACT_CASHFLOW (UNION ALL para inflows/outflows)
```

### 4. bi_views.sql + main_orchestrator.py (Exposición)
```
- Crear vistas para consumo del dashboard
- Exportar a formato Parquet
- Archivos: VW_DASHBOARD_MRR.parquet, VW_DASHBOARD_CAC.parquet, VW_DASHBOARD_CASHFLOW.parquet
```

## Ejecutando el Pipeline

### Instalación
```bash
pip install -r requirements.txt
```

### Ejecutar Pipeline
```bash
python main_orchestrator.py
```

Esto genera:
- `innova.duckdb` - Base de datos DuckDB con todas las tablas
- Archivos Parquet en `Outputs_parquet/`

### Consultar Base de Datos Directamente
```python
import duckdb
con = duckdb.connect('innova.duckdb')
con.sql('SELECT * FROM GOLD.VW_DASHBOARD_MRR LIMIT 10')
```

## Métricas de Negocio (Consultas de Ejemplo)

ubicadas en `sql/Ejem_consult_empresariales.sql`:

| Métrica | Consulta | Resultado |
|---------|----------|-----------|
| MRR Total Agosto 2024 | `SELECT SUM(G_MONTHLY_PRICE) FROM GOLD.FACT_MRR_MONTHLY WHERE G_MONTHS_ADD = '2024-08-01'` | $56,600 |
| Clientes Nuevos Q1 2024 | `SELECT COUNT(*) FROM SILVER.S_CUSTOMERS WHERE S_REGISTRATION_TIMESTAMP::DATE BETWEEN '2024-01-01' AND '2024-03-31'` | 235 |
| Gastos Marketing H1 2024 | `SELECT SUM(S_AMOUNT_USD) FROM SILVER.S_EXPENSES WHERE S_CATEGORY = 'MARKETING' AND S_EXPENSE_DATE::DATE BETWEEN '2024-01-01' AND '2024-06-30'` | $736,200 |
| FCF Diciembre 2024 | `SELECT SUM(G_NET_AMOUNT_USD) FROM GOLD.FACT_CASHFLOW WHERE G_FLOW_DATE::DATE BETWEEN '2024-12-01' AND '2024-12-31'` | -$533,861 |
| País con Mayor Ingreso | Junta payments con transactions | Estados Unidos ($268,366) |
| CAC Promedio Anual | Gastos marketing / Clientes nuevos | $1,499.35 |

## Detalles Técnicos Importantes

### Características de DuckDB Utilizadas
- **Recursive CTEs**: Para generación de dimensión de fecha y gap-filling de MRR
- **QUALIFY**: Para deduplicación sin subconsultas
- **TRY_CAST**: Conversión segura de tipos (retorna NULL en lugar de error)
- **COPY TO**: Exportación Parquet con compresión
- **Aislamiento de esquemas**: Esquemas RAW, SILVER, GOLD
- **UNION ALL**: Combinando inflows/outflows en FACT_CASHFLOW

### Convenciones de Nombres de Columnas
- **RAW**: Nombres originales de columnas (normalizados a minúsculas, snake_case)
- **SILVER**: Prefijo `S_` (ej. `S_CUSTOMER_ID`, `S_AMOUNT_USD`)
- **GOLD**: Prefijo `G_` para tablas de hechos (ej. `G_MONTHLY_PRICE`, `G_NET_AMOUNT_USD`)
- **Vistas**: Prefijo descriptivo `VW_DASHBOARD_` para consumo BI

### Columnas de Auditoría
- `filename`: Nombre del archivo CSV fuente para trazabilidad
- `load_date`: Timestamp cuando los datos se cargaron a la capa RAW
- `S_LOAD_TIMESTAMP`: Timestamp cuando los datos se transformaron a la capa SILVER

### Lógica de Gap-Filling de MRR
La tabla `FACT_MRR_MONTHLY` usa una recursive CTE para generar una fila por cada mes que la suscripción estuvo activa:
- Partiendo de `S_START_DATE`, agrega filas para cada mes hasta `S_END_DATE`
- Esto permite el cálculo correcto del MRR incluso cuando las suscripciones abarcan varios meses
- Filtra por año 2024 en la consulta final

### Cálculo de Flujo de Caja
`FACT_CASHFLOW` combina:
- **INFLOW** (montos positivos): Pagos de `S_PAYMENTS`
- **OUTFLOW** (montos negativos): Gastos de `S_EXPENSES` multiplicados por -1

## Integración con Power BI

Los archivos Parquet en `Outputs_parquet/` están diseñados para importación directa a Power BI:
- Formato columnar optimizado para lectura rápida
- Tamaño de archivo menor que CSV
- Conexión directa vía conector DuckDB o importación de archivo

El Dashboard (`DASHBOARD BI INNOVA.pbix`) incluye:
- **Evolución del MRR**: Tendencia mensual segmentada por tipo de plan
- **Análisis de CAC**: Costo de adquisición de clientes por canal
- **Cash Flow**: Comparación visual de Inflows vs Outflows

## Notas Importantes

- **Archivo de base de datos**: `innova.duckdb` (generado, debe estar en .gitignore)
- **Ubicación de archivos SQL**: Deben estar en el directorio `sql/`
- **Orden de ejecución**: silver_transformations.sql → gold_metrics.sql → bi_views.sql
- **Exportaciones Parquet**: Hardcodeadas en `main_orchestrator.py` líneas 38-43
- **Sintaxis de consultas**: Usar sintaxis nativa de DuckDB (no SQL estándar)
- **Manejo de fechas**: Usa `TRY_CAST` para parsing seguro de fechas

## Mejoras Futuras (Roadmap)

Ver README.md para el roadmap detallado:
- Contenedores Docker para reproducibilidad
- Integración con Great Expectations para calidad de datos
- Arquitectura event-driven con carga incremental
- Terraform IaC para infraestructura
- Soporte multi-moneda con tabla de tasas de cambio
- Llaves subrogadas usando MD5/SHA256 para unicidad global
- Particionamiento por año/mes/país para rendimiento
