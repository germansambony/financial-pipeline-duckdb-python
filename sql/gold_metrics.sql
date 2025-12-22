-------------- CAPA GOLD ----------------------
-- CONFIGURACION ESTRELLA
-- DIMESIONES TABLA DE FECHAS
-- HECHOS MRR_MONTHLY - CASHFLOW

CREATE SCHEMA IF NOT EXISTS GOLD;


-- 1. DIMENSIÓN FECHA (DIM_DATE)
-- Grano: un registro por cada día calendario.
-- Crea un calendario automático con recursividad, eficiencia para Power Bi
-- Parte dimensional de la configuracion estrella.

CREATE OR REPLACE TABLE GOLD.DIM_DATE AS
WITH RECURSIVE dates AS (
    SELECT CAST('2023-01-01' AS DATE) AS full_date
    UNION ALL
    SELECT full_date + INTERVAL 1 DAY
    FROM dates
    WHERE full_date < CAST('2025-12-31' AS DATE)
)
SELECT
    full_date                       AS DATE_ID,
    YEAR(full_date)                 AS YEAR,
    MONTH(full_date)                AS MONTH,
    QUARTER(full_date)              AS QUARTER,
    strftime(full_date, '%Y%m')     AS YEAR_MONTH
FROM dates;


-- 2. FACT_MRR_MONTHLY (Métrica: Monthly Recurring Revenue)
-- MRR: Ingresos recurrentes mensuales
-- Grano: Un registro por cada suscripción activa por cada mes transcurrido
-- Se añaden registros correspondientes a todos los meses de los intervalos de fecha START_DATE -> END_DATE
-- Se utiliza recursividad para el llenado de huecos

CREATE OR REPLACE TABLE GOLD.FACT_MRR_MONTHLY AS
WITH RECURSIVE ADD_MONTHS_REGISTERS AS (

    SELECT S_SUBSCRIPTION_ID,
           S_CUSTOMER_ID,
           S_PLAN_TYPE,
           S_MONTHLY_PRICE,
           DATE_TRUNC('month', S_START_DATE)::DATE AS MONTHS_ADD,
           S_STATUS,
           S_START_DATE,
           S_END_DATE
    FROM SILVER.S_SUBSCRIPTIONS
    WHERE S_STATUS IN ('ACTIVE', 'PAUSED') -- Contratos vigentes

    UNION ALL


    SELECT
        S_SUBSCRIPTION_ID,
        S_CUSTOMER_ID,
        S_PLAN_TYPE,
        S_MONTHLY_PRICE,
        MONTHS_ADD + INTERVAL 1 MONTH,
        S_STATUS,
        S_START_DATE,
        S_END_DATE
    FROM ADD_MONTHS_REGISTERS
    WHERE (MONTHS_ADD + INTERVAL 1 MONTH) <= S_END_DATE::DATE
)
SELECT
    S_SUBSCRIPTION_ID            AS G_SUBSCRIPTION_ID,
    S_CUSTOMER_ID                AS G_CUSTOMER_ID,
    S_PLAN_TYPE                  AS G_PLAN_TYPE,
    S_MONTHLY_PRICE              AS G_MONTHLY_PRICE,
    MONTHS_ADD                   AS G_MONTHS_ADD,
    S_STATUS                     AS G_STATUS,
    S_START_DATE                 AS G_S_START_DATE,
    S_END_DATE                   AS G_S_END_DATE,
    strftime(MONTHS_ADD, '%Y%m') AS G_YEAR_MONTH
FROM ADD_MONTHS_REGISTERS
WHERE YEAR(MONTHS_ADD) = 2024 --Año de interes
ORDER BY S_SUBSCRIPTION_ID,S_CUSTOMER_ID,S_PLAN_TYPE,MONTHS_ADD;


-- 3. FACT_CASHFLOW (Métrica: Free Cash Flow)
-- Grano: un registro por cada movimiento financiero individual
-- Categoriza el dinero que entra unido con el dinero que sale, en una sola tabla para eficiencia

CREATE OR REPLACE TABLE GOLD.FACT_CASHFLOW AS
-- Dinero que ENTRA (PAYMENTS)
SELECT
    S_PAYMENT_ID            AS G_TRANSACTION_REF,
    S_PAYMENT_DATE::DATE    AS G_FLOW_DATE,
    'INFLOW'                AS G_FLOW_TYPE,
    'SALES'                 AS G_CATEGORY,
    S_AMOUNT_USD            AS G_NET_AMOUNT_USD
FROM SILVER.S_PAYMENTS

UNION ALL

-- Dinero que SALE (EXPENSES)
SELECT
    S_EXPENSE_ID            AS G_TRANSACTION_REF,
    S_EXPENSE_DATE::DATE    AS G_FLOW_DATE,
    'OUTFLOW'               AS G_FLOW_TYPE,
    S_CATEGORY              AS G_CATEGORY,
    (S_AMOUNT_USD * -1)     AS G_NET_AMOUNT -- Negativo (-) IDETTIFICAR GASTOS Y SIMPLIFICAR PROCESOS
FROM SILVER.S_EXPENSES;
