# Innova DBT Project

Este proyecto es una refactorización del pipeline financiero de Innova utilizando **dbt (data build tool)** con DuckDB como base de datos.

## Estructura del Proyecto

```
innova_dbt/
├── dbt_project.yml          # Configuración principal del proyecto
├── profiles.yml             # Configuración de conexiones
├── models/
│   ├── bronze/
│   │   └── sources.yml      # Definición de fuentes (capa Bronze)
│   ├── silver/
│   │   ├── stg_customers.sql
│   │   ├── stg_employees.sql
│   │   ├── stg_transactions.sql
│   │   ├── stg_payments.sql
│   │   ├── stg_expenses.sql
│   │   ├── stg_subscriptions.sql
│   │   └── stg_subscriptions_errors.sql
│   └── gold/
│       ├── dim_date.sql
│       ├── fct_mrr_monthly.sql
│       ├── fct_cashflow.sql
│       ├── vw_dashboard_mrr.sql
│       ├── vw_dashboard_cac.sql
│       └── vw_dashboard_cashflow.sql
└── macros/                  # Macros personalizados (pendiente)
```

## Modelos

### Capa Silver (Limpieza y Transformación)

| Modelo | Descripción |
|--------|-------------|
| `stg_customers` | Clientes deduplicados con SCD Tipo 2 para país |
| `stg_employees` | Empleados deduplicados |
| `stg_transactions` | Transacciones limpiadas y deduplicadas |
| `stg_payments` | Pagos limpiados y deduplicados |
| `stg_expenses` | Gastos limpiados y deduplicados |
| `stg_subscriptions` | Suscripciones validadas (filtro de fechas) y deduplicadas |
| `stg_subscriptions_errors` | Registro de suscripciones rechazadas |

### Capa Gold (Modelado Dimensional)

| Modelo | Descripción | Materialización |
|--------|-------------|-----------------|
| `dim_date` | Dimensión de fecha (2023-2025) | Tabla |
| `fct_mrr_monthly` | Hechos de MRR mensual con gap-filling | Tabla |
| `fct_cashflow` | Hechos de flujo de caja (INFLOW/OUTFLOW) | Tabla |
| `vw_dashboard_mrr` | Vista de MRR para BI | Vista |
| `vw_dashboard_cac` | Vista de CAC para BI | Vista |
| `vw_dashboard_cashflow` | Vista de Cash Flow para BI | Vista |

## Tests

El proyecto incluye tests de calidad de datos definidos en `models/schema.yml`:

- **Unicidad**: Validación de claves únicas
- **No nulidad**: Validación de campos obligatorios
- **Relaciones**: Validación de integridad referencial
- **Valores aceptados**: Validación de dominios (ej. status de suscripciones)
- **Expresiones**: Validación de reglas de negocio (ej. precios >= 0)
- **Recencia**: Validación de frescura de datos

## Ejecución

### Requisitos Previos

1. Ejecutar el pipeline original (`python main_orchestrator.py`) para generar la capa Bronze en `innova.duckdb`.
2. Asegurarse de que las tablas RAW existan en la base de datos.

### Comandos DBT

```bash
# Ejecutar todos los modelos
dbt run

# Ejecutar solo modelos Silver
dbt run --select silver

# Ejecutar solo modelos Gold
dbt run --select gold

# Ejecutar tests
dbt test

# Generar documentación
dbt docs generate

# Ver documentación (servidor local)
dbt docs serve
```

## Configuración

El proyecto está configurado para conectar con DuckDB. La configuración de conexión se encuentra en `profiles.yml`.

## Mejoras Futuras

- [ ] Crear macros personalizados para lógica reutilizable
- [ ] Implementar tests adicionales de Great Expectations
- [ ] Configurar incremental materialization para grandes volúmenes
- [ ] Implementar Exposures para integración con herramientas de visualización
