{{ config(materialized='view', schema='GOLD') }}

SELECT
    d.YEAR,
    d.MONTH,
    d.QUARTER,
    d.YEAR_MONTH,
    G_FLOW_DATE::DATE       AS DATE,
    G_FLOW_TYPE,
    G_CATEGORY,
    SUM(G_NET_AMOUNT_USD)   AS AMOUNT,
    COUNT(*)                AS AGRUPADO
FROM {{ ref('fct_cashflow') }} fc
LEFT JOIN {{ ref('dim_date') }} d ON fc.G_FLOW_DATE::DATE = d.DATE_ID
GROUP BY 1, 2, 3, 4, 5, 6, 7
