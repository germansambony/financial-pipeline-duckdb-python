{{ config(materialized='incremental', schema='SILVER', unique_key='S_EXPENSE_ID') }}

SELECT
    TRIM(expense_id)                                 AS S_EXPENSE_ID,
    TRY_CAST(date AS TIMESTAMP)                      AS S_EXPENSE_DATE,
    NULLIF(TRIM(UPPER(provider)), '')                AS S_PROVIDER,
    NULLIF(TRIM(UPPER(category)), '')                AS S_CATEGORY,
    NULLIF(TRIM(UPPER(country)), '')                 AS S_COUNTRY,
    CAST(amount_usd AS DOUBLE)                       AS S_AMOUNT_USD,
    filename                                          AS S_FILENAME,
    CURRENT_TIMESTAMP                                 AS S_LOAD_TIMESTAMP
FROM {{ source('RAW', 'raw_expenses') }}
{% if is_incremental() %}
WHERE S_LOAD_TIMESTAMP > (SELECT COALESCE(MAX(S_LOAD_TIMESTAMP), '1900-01-01') FROM {{ this }})
{% endif %}
QUALIFY ROW_NUMBER() OVER (PARTITION BY expense_id ORDER BY date DESC) = 1
