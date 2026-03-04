{{ config(materialized='incremental', schema='SILVER', unique_key='S_SUBSCRIPTION_ID') }}

SELECT
    R.subscription_id                                 AS S_SUBSCRIPTION_ID,
    R.customer_id,
    R.start_date,
    R.end_date,
    R.status,
    R.filename                                       AS S_FILENAME,
    CASE
        WHEN CAST(COALESCE(R.end_date, '2099-12-31') AS DATE) < TRY_CAST(R.start_date AS DATE)
            THEN 'FECHA FIN INVALIDA (MENOR AL INICIO)'
        ELSE 'DUPLICADO'
    END AS MOTIVO_EXCLUSION
FROM {{ source('RAW', 'raw_subscriptions') }} R
LEFT JOIN {{ ref('stg_subscriptions') }} S
    ON TRIM(R.subscription_id) = S.S_SUBSCRIPTION_ID
    AND TRY_CAST(R.start_date AS TIMESTAMP) = S.S_START_DATE
WHERE S.S_SUBSCRIPTION_ID IS NULL
{% if is_incremental() %}
AND R.filename > (SELECT COALESCE(MAX(S_FILENAME), '') FROM {{ this }})
{% endif %}
