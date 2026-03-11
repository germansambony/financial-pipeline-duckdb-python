{{ config(materialized='incremental', schema='SILVER', unique_key='S_SUBSCRIPTION_ID') }}

SELECT
    TRIM(subscription_id)                            AS S_SUBSCRIPTION_ID,
    TRIM(customer_id)                                AS S_CUSTOMER_ID,
    NULLIF(TRIM(UPPER(plan)), '')                    AS S_PLAN_TYPE,
    TRY_CAST(start_date AS TIMESTAMP)                AS S_START_DATE,
    CAST(COALESCE(end_date, '2099-12-31') AS DATE)  AS S_END_DATE,
    NULLIF(TRIM(UPPER(status)), '')                   AS S_STATUS,
    CAST(monthly_price_usd AS DOUBLE)                AS S_MONTHLY_PRICE,
    CASE
        WHEN UPPER(status) = 'ACTIVE'
         AND (end_date IS NULL OR end_date::DATE > CURRENT_DATE)
        THEN TRUE
        ELSE FALSE
    END                                               AS IS_ACTIVE_TODAY,
    filename                                          AS S_FILENAME,
    CURRENT_TIMESTAMP                                 AS S_LOAD_TIMESTAMP
FROM {{ source('RAW', 'raw_subscriptions') }}
WHERE 1=1

{% if is_incremental() %}
    AND S_LOAD_TIMESTAMP > (
        SELECT COALESCE(MAX(S_LOAD_TIMESTAMP), '1900-01-01')
        FROM {{ this }}
    )
{% endif %}

AND CAST(COALESCE(end_date, '2099-12-31') AS DATE) 
    >= TRY_CAST(start_date AS DATE)

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY subscription_id 
    ORDER BY start_date DESC
) = 1
