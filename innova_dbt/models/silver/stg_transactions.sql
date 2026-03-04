{{ config(materialized='incremental', schema='SILVER', unique_key='S_TRANSACTION_ID') }}

SELECT
    TRIM(transaction_id)                             AS S_TRANSACTION_ID,
    TRIM(customer_id)                                AS S_CUSTOMER_ID,
    TRIM(product_id)                                 AS S_PRODUCT_ID,
    TRY_CAST(date AS TIMESTAMP)                      AS S_TRANSACTION_DATE,
    NULLIF(TRIM(UPPER(country)), '')                 AS S_COUNTRY,
    CAST(quantity AS INTEGER)                         AS S_QUANTITY,
    CAST(unit_price_usd AS DOUBLE)                   AS S_UNIT_PRICE_USD,
    CAST(total_usd AS DOUBLE)                        AS S_TOTAL_USD,
    filename                                          AS S_FILENAME,
    CURRENT_TIMESTAMP                                 AS S_LOAD_TIMESTAMP
FROM {{ source('RAW', 'raw_transactions') }}
{% if is_incremental() %}
WHERE S_LOAD_TIMESTAMP > (SELECT COALESCE(MAX(S_LOAD_TIMESTAMP), '1900-01-01') FROM {{ this }})
{% endif %}
QUALIFY ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY date DESC) = 1
