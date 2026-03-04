# AGENTS.md - Financial Pipeline DuckDB

## Project Overview

This is an **End-to-End Data Pipeline** for a SaaS company that transforms raw transactional data into a modern **Data Warehouse** using:
- **DuckDB** as the OLAP engine
- **Medallion Architecture** (Bronze → Silver → Gold)
- **Kimball's Dimensional Modeling** (Star Schema)
- **Python orchestration** for ELT process
- **Parquet exports** for Power BI consumption

## Repository Structure

```
├── main_orchestrator.py      # Main pipeline orchestration
├── extract.py                # CSV extraction and RAW layer loading
├── innova.duckdb             # DuckDB database file (generated)
├── requirements.txt          # Python dependencies
├── sql/
│   ├── silver_transformations.sql  # Cleaning, deduplication, SCD
│   ├── gold_metrics.sql             # Fact tables and metrics
│   ├── bi_views.sql                 # Views for Power BI
│   └── Ejem_consult_empresariales.sql
├── data/                     # Source CSV files
├── Outputs_parquet/          # Generated Parquet files
└── DASHBOARD BI INNOVA.pbix  # Power BI dashboard
```

## Data Architecture (Medallion)

### Bronze Layer (RAW)
- Raw CSV ingestion with metadata (`filename`, `load_date`)
- Immutable source data

### Silver Layer
- Deduplication
- SCD Type 2 for geography (historical tracking)
- SCD Type 1 for non-historical attributes
- Error table `S_TABLA_ERROR` for invalid subscriptions

### Gold Layer
- `FACT_MRR_MONTHLY`: Monthly recurring revenue with gap-filling
- `FACT_CASHFLOW`: Cash inflows/outflows
- `DIM_DATE`: Time dimension

## Running the Pipeline

```bash
# Install dependencies
pip install -r requirements.txt

# Run full pipeline
python main_orchestrator.py
```

This generates `innova.duckdb` and exports Parquet files to `Outputs_parquet/`.

## Key Tables

| Layer | Table | Description |
|-------|-------|-------------|
| RAW | Source tables from CSV | Ingested data |
| SILVER | S_CUSTOMERS, S_EMPLOYEES, S_EXPENSES | Cleaned dimensions |
| GOLD | FACT_MRR_MONTHLY | Monthly recurring revenue |
| GOLD | FACT_CASHFLOW | Net cash flow |
| GOLD | DIM_DATE | Time dimension |
| GOLD | VW_DASHBOARD_* | BI views |

## Important Notes

- Database file: `innova.duckdb`
- All SQL files must be in the `sql/` directory
- The orchestrator executes SQL files in order: silver → gold → bi_views
- Parquet exports are hardcoded in `main_orchestrator.py`
- Use DuckDB native syntax for queries
