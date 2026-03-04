{{ config(materialized='view', schema='GOLD') }}

WITH marketing_costs AS (
    SELECT
        DATE_TRUNC('month', S_EXPENSE_DATE)::DATE   AS MONTH,
        S_COUNTRY                                   AS COUNTRY,
        SUM(S_AMOUNT_USD)                           AS TOTAL_MARKETING_COST
    FROM {{ ref('stg_expenses') }}
    WHERE S_CATEGORY = 'MARKETING'
    GROUP BY 1, 2
),
new_customers AS (
    SELECT
        DATE_TRUNC('month', S_REGISTRATION_TIMESTAMP)::DATE AS MONTH,
        S_COUNTRY                                           AS COUNTRY,
        S_ACQUISITION_CHANNEL                               AS ACQUISITION_CHANNEL,
        COUNT(S_CUSTOMER_ID)                                AS NEW_CLIENTS
    FROM {{ ref('stg_customers') }}
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
    ROUND(mc.TOTAL_MARKETING_COST / NULLIF(nc.NEW_CLIENTS, 0), 2) AS CAC
FROM marketing_costs mc
LEFT JOIN new_customers nc ON (mc.MONTH = nc.MONTH AND mc.COUNTRY = nc.COUNTRY)
LEFT JOIN {{ ref('dim_date') }} d ON mc.MONTH = d.DATE_ID
