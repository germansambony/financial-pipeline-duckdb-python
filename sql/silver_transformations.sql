------------------------------- CAPA SILVER -------------------------------------

-- LIMPIEZA + TRANSFORMACION DE DATOS
-- ELIMINACION DE DUPLICADOS
-- CADA CASTEO SE REALIZA SEGUN EL SIGNIFICADO Y LA NATURALIDAD DE LOS DATOS
-- SE CREA COLUMNA QUE IDENTIFICA EL MOMENTO DE CARGA DE LOS DATOS A LA CAPA SILVER PARA MONITOREO Y SOPORTE
-- SE AÑADE EL ORIGEN DEL ARCHIVO PARA TRAZABILIDAD

CREATE SCHEMA IF NOT EXISTS SILVER;


-- 1. CLIENTES:
-- Grano: Un registro por customer_id (Primary key) y country
-- Para Slowly Changing Dimensions SCD Tipo 2 


CREATE OR REPLACE TABLE SILVER.S_CUSTOMERS AS
SELECT
    TRIM(customer_id)                                AS S_CUSTOMER_ID,
    NULLIF(TRIM(UPPER(country)),'')                  AS S_COUNTRY,
    NULLIF(TRIM(LOWER(acquisition_channel)),'')      AS S_ACQUISITION_CHANNEL,
    NULLIF(TRIM(UPPER(segment)),'')                  AS S_SEGMENT,
    TRY_CAST(registration_date AS TIMESTAMP)         AS S_REGISTRATION_TIMESTAMP,
    filename                                         AS S_FILENAME,
    CURRENT_TIMESTAMP                                AS S_LOAD_TIMESTAMP,
     CASE
        WHEN ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY registration_date DESC
        ) = 1
        THEN TRUE
        ELSE FALSE
    END                                             AS IS_CURRENT
FROM raw_customers
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id,country ORDER BY registration_date DESC) = 1;



-- 2. EMPLEADOS
-- Grano: Un registro por employee_id (Primary key)

CREATE OR REPLACE TABLE SILVER.S_EMPLOYEES AS
SELECT
    TRIM(employee_id)                                AS S_EMPLOYEE_ID,
    NULLIF(TRIM(UPPER(area)), '')                    AS S_AREA,
    CAST(salary_usd AS DOUBLE)                       AS S_SALARY_USD,
    NULLIF(TRIM(UPPER(country)), '')                 AS S_COUNTRY,
    TRY_CAST(hire_date AS TIMESTAMP)                 AS S_HIRE_DATE,
    filename                                         AS S_FILENAME,
    CURRENT_TIMESTAMP                                AS S_LOAD_TIMESTAMP
FROM raw_employees
QUALIFY ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY hire_date DESC) = 1;


-- 3 TRANSACCIONES (VENTAS)
-- Grano: Un registro por transaction_id (Primary key)

CREATE OR REPLACE TABLE SILVER.S_TRANSACTIONS AS
SELECT
    TRIM(transaction_id)                             AS S_TRANSACTION_ID,
    TRIM(customer_id)                                AS S_CUSTOMER_ID,
    TRIM(product_id)                                 AS S_PRODUCT_ID,
    TRY_CAST(date AS TIMESTAMP)                      AS S_TRANSACTION_DATE,
    NULLIF(TRIM(UPPER(country)), '')                 AS S_COUNTRY,
    CAST(quantity AS INTEGER)                        AS S_QUANTITY,
    CAST(unit_price_usd AS DOUBLE)                   AS S_UNIT_PRICE_USD,
    CAST(total_usd AS DOUBLE)                        AS S_TOTAL_USD,
    filename                                         AS S_FILENAME,
    CURRENT_TIMESTAMP                                AS S_LOAD_TIMESTAMP
FROM raw_transactions
QUALIFY ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY date DESC) = 1;


-- 4. PAGOS
-- Grano: Un registro por payment_id (Primary key)

CREATE OR REPLACE TABLE SILVER.S_PAYMENTS AS
SELECT
    TRIM(payment_id)                                 AS S_PAYMENT_ID,
    TRIM(transaction_id)                             AS S_TRANSACTION_ID,
    TRY_CAST(payment_date AS TIMESTAMP)              AS S_PAYMENT_DATE,
    NULLIF(TRIM(UPPER(method)),'')                   AS S_PAYMENT_METHOD,
    CAST(amount_usd AS DOUBLE)                       AS S_AMOUNT_USD,
    filename                                         AS S_FILENAME,
    CURRENT_TIMESTAMP                                AS S_LOAD_TIMESTAMP
FROM raw_payments
QUALIFY ROW_NUMBER() OVER (PARTITION BY payment_id ORDER BY payment_date DESC) = 1;


-- 5. GASTOS (CASH OUT)
-- Grano: Un registro por expense_id (Primary key)

CREATE OR REPLACE TABLE SILVER.S_EXPENSES AS
SELECT
    TRIM(expense_id)                                 AS S_EXPENSE_ID,
    TRY_CAST(date AS TIMESTAMP)                      AS S_EXPENSE_DATE,
    NULLIF(TRIM(UPPER(provider)), '')                AS S_PROVIDER,
    NULLIF(TRIM(UPPER(category)), '')                AS S_CATEGORY,
    NULLIF(TRIM(UPPER(country)), '')                 AS S_COUNTRY,
    CAST(amount_usd AS DOUBLE)                       AS S_AMOUNT_USD,
    filename                                         AS S_FILENAME,
    CURRENT_TIMESTAMP                                AS S_LOAD_TIMESTAMP
FROM raw_expenses
QUALIFY ROW_NUMBER() OVER (PARTITION BY expense_id ORDER BY date DESC) = 1;


-- 6. SUSCRIPCIONES
-- Grano: Un registro por subscription_id (Primary key)
-- SE FILTRAN REGISTROS POR FECHA FIN INVALIDA (MENOR AL INICIO) - EN ESTA PRUEBA 741
-- PRESENTES EN LA TABLA DE ERROR


CREATE OR REPLACE TABLE SILVER.S_SUBSCRIPTIONS AS
SELECT
    TRIM(subscription_id)                                   AS S_SUBSCRIPTION_ID,
    TRIM(customer_id)                                       AS S_CUSTOMER_ID,
    NULLIF(TRIM(UPPER(plan)), '')                           AS S_PLAN_TYPE,
    TRY_CAST(start_date AS TIMESTAMP)                       AS S_START_DATE,
    -- FECHA LEJANA POR SI NO TIENE END_DATE LA SUBS
    CAST(COALESCE(end_date, '2099-12-31') AS DATE )         AS S_END_DATE,
    NULLIF(TRIM(UPPER(status)), '')                         AS S_STATUS,
    CAST(monthly_price_usd AS DOUBLE)                       AS S_MONTHLY_PRICE,
    CASE
        WHEN UPPER(status) = 'ACTIVE'
         AND (end_date IS NULL OR end_date::DATE > CURRENT_DATE)
        THEN TRUE
        ELSE FALSE
    END                                                     AS IS_ACTIVE_TODAY, -- EJEMPLO DE OPERACION (ESTA ACTIVA HOY?)
    filename                                                AS S_FILENAME,
    CURRENT_TIMESTAMP                                       AS S_LOAD_TIMESTAMP
FROM raw_subscriptions
WHERE CAST(COALESCE(end_date, '2099-12-31') AS DATE ) >= TRY_CAST(start_date AS DATE)
QUALIFY ROW_NUMBER() OVER (PARTITION BY subscription_id ORDER BY start_date DESC) = 1;


--  7 . REGISTROS FILTRADOS (RAW VS SILVER)
--  EJEMPLO CON LA TABLA DE SUBSCRIPTIONS PARA IDENTIFICAR REGISTROS DESCARTADOS DURANTE EL PROCESO DE LIMPIEZA.

CREATE OR REPLACE TABLE SILVER.S_TABLA_ERROR AS
SELECT
    R.subscription_id,
    R.customer_id,
    R.start_date,
    R.end_date,
    R.status,
    R.filename,
    CASE
        -- CASO 1: EL REGISTRO FALLÓ EL FILTRO DE FECHAS (END < START)
        WHEN CAST(COALESCE(R.end_date, '2099-12-31') AS DATE) < TRY_CAST(R.start_date AS DATE)
            THEN 'FECHA FIN INVALIDA (MENOR AL INICIO)'

        -- CASO 2: EL REGISTRO ES UN DUPLICADO
        ELSE 'DUPLICADO'
    END AS MOTIVO_EXCLUSION
FROM raw_subscriptions R
LEFT JOIN SILVER.S_SUBSCRIPTIONS S
    ON TRIM(R.subscription_id) = S.S_SUBSCRIPTION_ID
    AND TRY_CAST(R.start_date AS TIMESTAMP) = S.S_START_DATE

WHERE S.S_SUBSCRIPTION_ID IS NULL; -- SOLO LOS QUE NO PASARON A SILVER
