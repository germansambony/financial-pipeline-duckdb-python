# AGENTS.md - Financial Pipeline DuckDB

## Project Overview

This is an **End-to-End Data Pipeline** for a SaaS company called "Innova" that transforms raw transactional data into a modern **Data Warehouse** using:
- **DuckDB** as the OLAP engine
- **Medallion Architecture** (Bronze → Silver → Gold)
- **Kimball's Dimensional Modeling** (Star Schema)
- **Python orchestration** for ELT process
- **Parquet exports** for Power BI consumption

## Repository Structure

```
├── main_orchestrator.py          # Main pipeline orchestration
├── extract.py                    # CSV extraction and RAW layer loading
├── innova.duckdb                 # DuckDB database file (generated)
├── requirements.txt              # Python dependencies
├── README.md                     # Project documentation
├── sql/
│   ├── silver_transformations.sql  # Cleaning, deduplication, SCD
│   ├── gold_metrics.sql             # Fact tables and metrics
│   ├── bi_views.sql                 # Views for Power BI
│   └── Ejem_consult_empresariales.sql  # Business queries examples
├── data/                          # Source CSV files
│   ├── customers.csv               # Customer data (~1000 records)
│   ├── subscriptions.csv           # Subscription data (~2000 records)
│   ├── transactions.csv             # Sales transactions
│   ├── payments.csv                # Payment records
│   ├── expenses.csv                # Operating expenses
│   └── employees.csv               # Employee data
├── Outputs_parquet/               # Generated Parquet files
│   ├── VW_DASHBOARD_MRR.parquet
│   ├── VW_DASHBOARD_CAC.parquet
│   └── VW_DASHBOARD_CASHFLOW.parquet
└── DASHBOARD BI INNOVA.pbix       # Power BI dashboard
```

## Architecture (Medallion)

### Bronze Layer (RAW)
- Raw CSV ingestion with metadata (`filename`, `load_date`)
- Immutable source data
- Tables: `raw_customers`, `raw_subscriptions`, `raw_transactions`, `raw_payments`, `raw_expenses`, `raw_employees`

### Silver Layer
- **Deduplication** using `QUALIFY ROW_NUMBER()` to keep latest records
- **SCD Type 2** for geography (`country` in customers)
- **SCD Type 1** for non-historical attributes
- **Error handling** with `S_TABLA_ERROR` table for invalid subscriptions
- Tables: `S_CUSTOMERS`, `S_EMPLOYEES`, `S_TRANSACTIONS`, `S_PAYMENTS`, `S_EXPENSES`, `S_SUBSCRIPTIONS`, `S_TABLA_ERROR`

### Gold Layer
- **Star Schema** with fact and dimension tables
- **FACT_MRR_MONTHLY**: Monthly recurring revenue with gap-filling (recursive CTE)
- **FACT_CASHFLOW**: Cash inflows/outflows
- **DIM_DATE**: Time dimension (2023-2025)
- Views: `VW_DASHBOARD_MRR`, `VW_DASHBOARD_CAC`, `VW_DASHBOARD_CASHFLOW`

## Data Model

### Source Data Schema (CSV)

| File | Columns |
|------|---------|
| customers.csv | customer_id, country, acquisition_channel, segment, registration_date |
| subscriptions.csv | subscription_id, customer_id, plan, start_date, end_date, status, monthly_price_usd |
| transactions.csv | transaction_id, customer_id, product_id, date, country, quantity, unit_price_usd, total_usd |
| payments.csv | payment_id, transaction_id, payment_date, method, amount_usd |
| expenses.csv | expense_id, date, provider, category, country, amount_usd |
| employees.csv | employee_id, area, salary_usd, country, hire_date |

### Silver Layer Schema

| Table | Key Columns | Description |
|-------|-------------|-------------|
| S_CUSTOMERS | S_CUSTOMER_ID, S_COUNTRY, S_ACQUISITION_CHANNEL, S_SEGMENT, S_REGISTRATION_TIMESTAMP, IS_CURRENT | Deduplicated customers with SCD Type 2 for country |
| S_EMPLOYEES | S_EMPLOYEE_ID, S_AREA, S_SALARY_USD, S_COUNTRY, S_HIRE_DATE | Deduplicated employees |
| S_TRANSACTIONS | S_TRANSACTION_ID, S_CUSTOMER_ID, S_PRODUCT_ID, S_TRANSACTION_DATE, S_COUNTRY, S_QUANTITY, S_UNIT_PRICE_USD, S_TOTAL_USD | Cleaned transactions |
| S_PAYMENTS | S_PAYMENT_ID, S_TRANSACTION_ID, S_PAYMENT_DATE, S_PAYMENT_METHOD, S_AMOUNT_USD | Cleaned payments |
| S_EXPENSES | S_EXPENSE_ID, S_EXPENSE_DATE, S_PROVIDER, S_CATEGORY, S_COUNTRY, S_AMOUNT_USD | Cleaned expenses |
| S_SUBSCRIPTIONS | S_SUBSCRIPTION_ID, S_CUSTOMER_ID, S_PLAN_TYPE, S_START_DATE, S_END_DATE, S_STATUS, S_MONTHLY_PRICE, IS_ACTIVE_TODAY | Validated subscriptions |
| S_TABLA_ERROR | subscription_id, customer_id, start_date, end_date, status, filename, MOTIVO_EXCLUSION | Rejected subscription records |

### Gold Layer Schema

| Table | Key Columns | Grain |
|-------|-------------|-------|
| DIM_DATE | DATE_ID, YEAR, MONTH, QUARTER, YEAR_MONTH | One row per calendar day |
| FACT_MRR_MONTHLY | G_SUBSCRIPTION_ID, G_CUSTOMER_ID, G_PLAN_TYPE, G_MONTHLY_PRICE, G_MONTHS_ADD, G_STATUS, G_YEAR_MONTH | One row per active subscription per month |
| FACT_CASHFLOW | G_TRANSACTION_REF, G_FLOW_DATE, G_FLOW_TYPE (INFLOW/OUTFLOW), G_CATEGORY, G_NET_AMOUNT_USD | One row per financial movement |
| VW_DASHBOARD_MRR | DATE_MONTH, COUNTRY, PLAN, TOTAL_MRR | Aggregated MRR by month/country/plan |
| VW_DASHBOARD_CAC | YEAR, MONTH, QUARTER, YEAR_MONTH, MONTH_DATE, COUNTRY, TOTAL_MARKETING_COST, NEW_CLIENTS, ACQUISITION_CHANNEL, CAC | CAC metrics by channel |
| VW_DASHBOARD_CASHFLOW | YEAR, MONTH, QUARTER, YEAR_MONTH, DATE, G_FLOW_TYPE, G_CATEGORY, AMOUNT, AGRUPADO | Cash flow aggregation |

## Pipeline Flow

### 1. extract.py (EL - Extract & Load)
```
- Read CSV files from data/ folder
- Add audit columns: filename, load_date
- Normalize column names (lowercase, snake_case)
- Create RAW tables in DuckDB
```

### 2. silver_transformations.sql (T - Transform)
```
- Deduplicate using QUALIFY ROW_NUMBER()
- Type casting (TRY_CAST, CAST)
- SCD Type 2 logic for customer geography
- Data validation (end_date >= start_date)
- Create error table for rejected records
```

### 3. gold_metrics.sql (Modeling)
```
- Generate DIM_DATE (recursive CTE: 2023-2025)
- Create FACT_MRR_MONTHLY with gap-filling (recursive CTE)
- Create FACT_CASHFLOW (UNION ALL for inflows/outflows)
```

### 4. bi_views.sql + main_orchestrator.py (Exposure)
```
- Create views for dashboard consumption
- Export to Parquet format
- Files: VW_DASHBOARD_MRR.parquet, VW_DASHBOARD_CAC.parquet, VW_DASHBOARD_CASHFLOW.parquet
```

## Running the Pipeline

### Installation
```bash
pip install -r requirements.txt
```

### Execute Pipeline
```bash
python main_orchestrator.py
```

This generates:
- `innova.duckdb` - DuckDB database with all tables
- Parquet files in `Outputs_parquet/`

### Query Database Directly
```python
import duckdb
con = duckdb.connect('innova.duckdb')
con.sql('SELECT * FROM GOLD.VW_DASHBOARD_MRR LIMIT 10')
```

## Business Metrics (Sample Queries)

Located in `sql/Ejem_consult_empresariales.sql`:

| Metric | Query | Result |
|--------|-------|--------|
| MRR Total August 2024 | `SELECT SUM(G_MONTHLY_PRICE) FROM GOLD.FACT_MRR_MONTHLY WHERE G_MONTHS_ADD = '2024-08-01'` | $56,600 |
| New Customers Q1 2024 | `SELECT COUNT(*) FROM SILVER.S_CUSTOMERS WHERE S_REGISTRATION_TIMESTAMP::DATE BETWEEN '2024-01-01' AND '2024-03-31'` | 235 |
| Marketing Expenses H1 2024 | `SELECT SUM(S_AMOUNT_USD) FROM SILVER.S_EXPENSES WHERE S_CATEGORY = 'MARKETING' AND S_EXPENSE_DATE::DATE BETWEEN '2024-01-01' AND '2024-06-30'` | $736,200 |
| FCF December 2024 | `SELECT SUM(G_NET_AMOUNT_USD) FROM GOLD.FACT_CASHFLOW WHERE G_FLOW_DATE::DATE BETWEEN '2024-12-01' AND '2024-12-31'` | -$533,861 |
| Country with Highest Revenue | Query joins payments with transactions | United States ($268,366) |
| Annual Avg CAC | Marketing costs / New customers | $1,499.35 |

## Key Technical Details

### DuckDB Features Used
- **Recursive CTEs**: For date dimension generation and MRR gap-filling
- **QUALIFY**: For deduplication without subqueries
- **TRY_CAST**: Safe type conversion (returns NULL instead of error)
- **COPY TO**: Parquet export with compression
- **Schema isolation**: RAW, SILVER, GOLD schemas
- **UNION ALL**: Combining inflows/outflows in FACT_CASHFLOW

### Column Naming Conventions
- **RAW**: Original column names (normalized to lowercase, snake_case)
- **SILVER**: Prefix `S_` (e.g., `S_CUSTOMER_ID`, `S_AMOUNT_USD`)
- **GOLD**: Prefix `G_` for fact tables (e.g., `G_MONTHLY_PRICE`, `G_NET_AMOUNT_USD`)
- **Views**: Descriptive prefix `VW_DASHBOARD_` for BI consumption

### Audit Columns
- `filename`: Source CSV filename for traceability
- `load_date`: Timestamp when data was loaded to RAW layer
- `S_LOAD_TIMESTAMP`: Timestamp when data was transformed to SILVER layer

### MRR Gap-Filling Logic
The `FACT_MRR_MONTHLY` table uses a recursive CTE to generate one row per subscription for each month it was active:
- Starting from `S_START_DATE`, adds rows for each month until `S_END_DATE`
- This enables proper MRR calculation even when subscriptions span multiple months
- Filters for year 2024 in final query

### Cash Flow Calculation
`FACT_CASHFLOW` combines:
- **INFLOW** (positive amounts): Payments from `S_PAYMENTS`
- **OUTFLOW** (negative amounts): Expenses from `S_EXPENSES` multiplied by -1

## Power BI Integration

The Parquet files in `Outputs_parquet/` are designed for direct Power BI import:
- Optimized columnar format for fast reading
- Smaller file size than CSV
- Direct connection via DuckDB connector or file import

Dashboard (`DASHBOARD BI INNOVA.pbix`) includes:
- **MRR Evolution**: Monthly trend segmented by plan type
- **CAC Analysis**: Customer acquisition cost by channel
- **Cash Flow**: Visual comparison of Inflows vs Outflows

## Important Notes

- **Database file**: `innova.duckdb` (generated, should be in .gitignore)
- **SQL files location**: Must be in `sql/` directory
- **Execution order**: silver_transformations.sql → gold_metrics.sql → bi_views.sql
- **Parquet exports**: Hardcoded in `main_orchestrator.py` lines 38-43
- **Query syntax**: Use DuckDB native syntax (not standard SQL)
- **Date handling**: Uses `TRY_CAST` for safe date parsing

## Future Enhancements (Roadmap)

See README.md for detailed roadmap:
- Docker containerization for reproducibility
- Great Expectations integration for data quality
- Event-driven architecture with incremental loading
- Terraform IaC for infrastructure
- Multi-currency support with FX rate table
- Surrogate keys using MD5/SHA256 for global uniqueness
- Partitioning by year/month/country for performance
