{{ config(materialized='incremental', schema='SILVER', unique_key='S_CUSTOMER_ID') }}

SELECT
    TRIM(customer_id)                                AS S_CUSTOMER_ID,
    NULLIF(TRIM(UPPER(country)),'')                  AS S_COUNTRY,
    NULLIF(TRIM(LOWER(acquisition_channel)),'')       AS S_ACQUISITION_CHANNEL,
    NULLIF(TRIM(UPPER(segment)),'')                   AS S_SEGMENT,
    TRY_CAST(registration_date AS TIMESTAMP)          AS S_REGISTRATION_TIMESTAMP,
    filename                                          AS S_FILENAME,
    CURRENT_TIMESTAMP                                 AS S_LOAD_TIMESTAMP,
    CASE
        WHEN ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY registration_date DESC
        ) = 1
        THEN TRUE
        ELSE FALSE
    END                                               AS IS_CURRENT
FROM {{ source('RAW', 'raw_customers') }}
{% if is_incremental() %}
WHERE S_LOAD_TIMESTAMP > (SELECT COALESCE(MAX(S_LOAD_TIMESTAMP), '1900-01-01') FROM {{ this }})
{% endif %}
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id, country ORDER BY registration_date DESC) = 1
