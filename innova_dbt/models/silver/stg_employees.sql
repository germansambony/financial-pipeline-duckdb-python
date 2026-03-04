{{ config(materialized='incremental', schema='SILVER', unique_key='S_EMPLOYEE_ID') }}

SELECT
    TRIM(employee_id)                                AS S_EMPLOYEE_ID,
    NULLIF(TRIM(UPPER(area)), '')                   AS S_AREA,
    CAST(salary_usd AS DOUBLE)                      AS S_SALARY_USD,
    NULLIF(TRIM(UPPER(country)), '')                AS S_COUNTRY,
    TRY_CAST(hire_date AS TIMESTAMP)                AS S_HIRE_DATE,
    filename                                          AS S_FILENAME,
    CURRENT_TIMESTAMP                                 AS S_LOAD_TIMESTAMP
FROM {{ source('RAW', 'raw_employees') }}
{% if is_incremental() %}
WHERE S_LOAD_TIMESTAMP > (SELECT COALESCE(MAX(S_LOAD_TIMESTAMP), '1900-01-01') FROM {{ this }})
{% endif %}
QUALIFY ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY hire_date DESC) = 1
