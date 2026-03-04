{{ config(materialized='table', schema='GOLD') }}

WITH RECURSIVE dates AS (
    SELECT CAST('2023-01-01' AS DATE) AS full_date
    UNION ALL
    SELECT full_date + INTERVAL 1 DAY
    FROM dates
    WHERE full_date < CAST('2025-12-31' AS DATE)
)
SELECT
    full_date                       AS DATE_ID,
    YEAR(full_date)                 AS YEAR,
    MONTH(full_date)                AS MONTH,
    QUARTER(full_date)              AS QUARTER,
    strftime(full_date, '%Y%m')     AS YEAR_MONTH
FROM dates
