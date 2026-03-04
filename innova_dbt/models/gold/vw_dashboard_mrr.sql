{{ config(materialized='view', schema='GOLD') }}

SELECT
    m.G_YEAR_MONTH              AS DATE_MONTH,
    c.S_COUNTRY                 AS COUNTRY,
    m.G_PLAN_TYPE               AS PLAN,
    SUM(m.G_MONTHLY_PRICE)      AS TOTAL_MRR
FROM {{ ref('fct_mrr_monthly') }} m
JOIN {{ ref('stg_customers') }} c ON m.G_CUSTOMER_ID = c.S_CUSTOMER_ID
GROUP BY 1, 2, 3
