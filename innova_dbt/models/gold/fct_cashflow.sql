{{ config(materialized='table', schema='GOLD') }}

WITH
payments AS (
    SELECT
        S_PAYMENT_ID         AS G_TRANSACTION_REF,
        S_PAYMENT_DATE::DATE AS G_FLOW_DATE,
        'INFLOW'             AS G_FLOW_TYPE,
        'SALES'              AS G_CATEGORY,
        S_AMOUNT_USD         AS G_NET_AMOUNT_USD
    FROM {{ ref('stg_payments') }}
),
expenses AS (
    SELECT
        S_EXPENSE_ID         AS G_TRANSACTION_REF,
        S_EXPENSE_DATE::DATE AS G_FLOW_DATE,
        'OUTFLOW'            AS G_FLOW_TYPE,
        S_CATEGORY            AS G_CATEGORY,
        (S_AMOUNT_USD * -1)  AS G_NET_AMOUNT_USD
    FROM {{ ref('stg_expenses') }}
)

SELECT * FROM payments
UNION ALL
SELECT * FROM expenses