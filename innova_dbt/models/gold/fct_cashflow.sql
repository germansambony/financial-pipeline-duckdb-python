{{ config(materialized='incremental', schema='GOLD', unique_key='G_TRANSACTION_REF') }}

SELECT
    S_PAYMENT_ID            AS G_TRANSACTION_REF,
    S_PAYMENT_DATE::DATE    AS G_FLOW_DATE,
    'INFLOW'                AS G_FLOW_TYPE,
    'SALES'                 AS G_CATEGORY,
    S_AMOUNT_USD            AS G_NET_AMOUNT_USD
FROM {{ ref('stg_payments') }}
{% if is_incremental() %}
WHERE S_LOAD_TIMESTAMP > (SELECT COALESCE(MAX(S_LOAD_TIMESTAMP), '1900-01-01') FROM {{ this }})
{% endif %}

UNION ALL

SELECT
    S_EXPENSE_ID            AS G_TRANSACTION_REF,
    S_EXPENSE_DATE::DATE    AS G_FLOW_DATE,
    'OUTFLOW'               AS G_FLOW_TYPE,
    S_CATEGORY              AS G_CATEGORY,
    (S_AMOUNT_USD * -1)    AS G_NET_AMOUNT_USD
FROM {{ ref('stg_expenses') }}
{% if is_incremental() %}
WHERE S_LOAD_TIMESTAMP > (SELECT COALESCE(MAX(S_LOAD_TIMESTAMP), '1900-01-01') FROM {{ this }})
{% endif %}
