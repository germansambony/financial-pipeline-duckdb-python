{{ config(materialized='incremental', schema='SILVER', unique_key='S_PAYMENT_ID') }}

SELECT
    TRIM(payment_id)                                 AS S_PAYMENT_ID,
    TRIM(transaction_id)                             AS S_TRANSACTION_ID,
    TRY_CAST(payment_date AS TIMESTAMP)              AS S_PAYMENT_DATE,
    NULLIF(TRIM(UPPER(method)),'')                   AS S_PAYMENT_METHOD,
    CAST(amount_usd AS DOUBLE)                       AS S_AMOUNT_USD,
    filename                                          AS S_FILENAME,
    CURRENT_TIMESTAMP                                 AS S_LOAD_TIMESTAMP
FROM {{ source('RAW', 'raw_payments') }}
{% if is_incremental() %}
WHERE S_LOAD_TIMESTAMP > (SELECT COALESCE(MAX(S_LOAD_TIMESTAMP), '1900-01-01') FROM {{ this }})
{% endif %}
QUALIFY ROW_NUMBER() OVER (PARTITION BY payment_id ORDER BY payment_date DESC) = 1
