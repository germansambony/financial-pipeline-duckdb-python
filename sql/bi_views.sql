-- CREACION DE VISTAS SEGUN NECESIDADES DEL CLIENTE
-- MAYOR EFICIENCIA PARA DATOS OPORTUNOS EN POWER BI

-- Vista de MRR para el Dash
-- Grano: un registro agregado por mes, país y tipo de plan.
CREATE OR REPLACE VIEW GOLD.VW_DASHBOARD_MRR AS
    SELECT
        m.G_YEAR_MONTH              AS DATE_MONTH,
        c.S_COUNTRY                 AS COUNTRY,
        m.G_PLAN_TYPE               AS PLAN,
        SUM(m.G_MONTHLY_PRICE)      AS TOTAL_MRR
    FROM GOLD.FACT_MRR_MONTHLY m
    JOIN SILVER.S_CUSTOMERS c ON m.G_CUSTOMER_ID = c.S_CUSTOMER_ID
    GROUP BY 1, 2, 3;

-- Vista para CAC (Coste de Adquisición)
-- Grano: un registro agregado por mes, país y canal de adquisición.

CREATE OR REPLACE VIEW GOLD.VW_DASHBOARD_CAC AS
    WITH marketing_costs AS (
        SELECT
            DATE_TRUNC('month', S_EXPENSE_DATE)::DATE   AS MONTH,
            S_COUNTRY                                   AS COUNTRY,
            SUM(S_AMOUNT_USD)                           AS TOTAL_MARKETING_COST
        FROM SILVER.S_EXPENSES
        WHERE S_CATEGORY = 'MARKETING'
        GROUP BY 1, 2
        ),
        new_customers AS (
            SELECT
                DATE_TRUNC('month', S_REGISTRATION_TIMESTAMP)::DATE AS MONTH,
                S_COUNTRY                                           AS COUNTRY,
                S_ACQUISITION_CHANNEL                               AS ACQUISITION_CHANNEL,
                COUNT(S_CUSTOMER_ID)                                AS NEW_CLIENTS
            FROM SILVER.S_CUSTOMERS
            GROUP BY 1, 2, 3
        )
        SELECT
            d.YEAR,
            d.MONTH,
            d.QUARTER,
            d.YEAR_MONTH,
            mc.MONTH                                                     AS MONTH_DATE,
            mc.COUNTRY,
            mc.TOTAL_MARKETING_COST,
            nc.NEW_CLIENTS,
            nc.ACQUISITION_CHANNEL,
            round(mc.TOTAL_MARKETING_COST / NULLIF(nc.NEW_CLIENTS, 0),2) AS CAC
        FROM marketing_costs mc
        LEFT JOIN new_customers nc ON (mc.MONTH = nc.MONTH AND mc.COUNTRY = nc.COUNTRY)  --LEFT POR SI EN UN MES GASTO DINERO PERO NO HUBO NUEVOS CLIENTES
        LEFT JOIN GOLD.DIM_DATE d ON mc.MONTH = d.DATE_ID;


-- Vista para Free Cash Flow (FCF)
-- Grano: un registro agregado por día, tipo de flujo (in/out) y categoria.

CREATE OR REPLACE VIEW GOLD.VW_DASHBOARD_CASHFLOW AS
    SELECT
        d.YEAR,
        d.MONTH,
        d.QUARTER,
        d.YEAR_MONTH,
        G_FLOW_DATE::DATE       AS DATE,
        G_FLOW_TYPE,
        G_CATEGORY,
        SUM(G_NET_AMOUNT_USD)   AS AMOUNT,
        count(*)                AS AGRUPADO
    FROM GOLD.FACT_CASHFLOW fc
    LEFT JOIN GOLD.DIM_DATE d ON fc.G_FLOW_DATE::DATE= d.DATE_ID
    GROUP BY 1, 2, 3 ,4 ,5 ,6 ,7;

/*

SCRIPT DE PYTHON PARA CARGAR A POWER BI

import duckdb
import pandas as pd
con = duckdb.connect(r"C:\Users\camil\OneDrive\Documentos\Alegra\innova_finance_datasets\innova.duckdb")

# Carga las vistas y tablas en formato parket
con.sql('COPY GOLD.VW_DASHBOARD_MRR TO "VW_DASHBOARD_MRR.parquet" (FORMAT PARQUET);')
con.sql('COPY GOLD.VW_DASHBOARD_CAC TO "VW_DASHBOARD_CAC.parquet" (FORMAT PARQUET);')
con.sql('COPY GOLD.VW_DASHBOARD_CASHFLOW TO "VW_DASHBOARD_CASHFLOW.parquet" (FORMAT PARQUET);')

*/