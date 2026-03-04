{{ config(materialized='table', schema='GOLD', unique_key='G_SUBSCRIPTION_ID || G_YEAR_MONTH') }}

WITH RECURSIVE ADD_MONTHS_REGISTERS AS (
    SELECT 
        S_SUBSCRIPTION_ID,
        S_CUSTOMER_ID,
        S_PLAN_TYPE,
        S_MONTHLY_PRICE,
        DATE_TRUNC('month', S_START_DATE)::DATE AS MONTHS_ADD,
        S_STATUS,
        S_START_DATE,
        S_END_DATE
    FROM {{ ref('stg_subscriptions') }}
    WHERE S_STATUS IN ('ACTIVE', 'PAUSED')
    {% if is_incremental() %}
    AND S_LOAD_TIMESTAMP > (SELECT COALESCE(MAX(S_LOAD_TIMESTAMP), '1900-01-01') FROM {{ this }})
    {% endif %}

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
    S_START_DATE                  AS G_S_START_DATE,
    S_END_DATE                    AS G_S_END_DATE,
    strftime(MONTHS_ADD, '%Y%m') AS G_YEAR_MONTH
FROM ADD_MONTHS_REGISTERS
WHERE YEAR(MONTHS_ADD) BETWEEN 2023 AND 2025
ORDER BY S_SUBSCRIPTION_ID, S_CUSTOMER_ID, S_PLAN_TYPE, MONTHS_ADD
