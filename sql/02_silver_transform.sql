-- ============================================================
-- 02_SILVER_TRANSFORM.sql
-- Layer: SILVER (clean, type, de-duplicate, harmonise, derive)
-- Engine: PostgreSQL
-- Input:  bronze.orders_raw  →  Output: silver.orders_clean
-- ------------------------------------------------------------
-- Demonstrates: CAST, NULLIF, COALESCE, CASE, date math, TRIM,
--               window functions (ROW_NUMBER) for de-dup, CTEs.
-- ============================================================

DROP SCHEMA IF EXISTS silver CASCADE;
CREATE SCHEMA silver;

CREATE TABLE silver.orders_clean AS
WITH typed AS (
    SELECT
        -- ---- identifiers (typed) ----
        NULLIF(order_id, '')::INT                         AS order_id,
        NULLIF(order_item_id, '')::INT                    AS order_item_id,
        NULLIF(customer_id, '')::INT                      AS customer_id,
        NULLIF(product_card_id, '')::INT                  AS product_id,
        NULLIF(category_id, '')::INT                      AS category_id,

        -- ---- dates (typed) ----
        TO_TIMESTAMP(order_date_dateorders, 'MM/DD/YYYY HH24:MI')::DATE     AS order_date,
        TO_TIMESTAMP(shipping_date_dateorders, 'MM/DD/YYYY HH24:MI')::DATE  AS shipping_date,

        -- ---- shipping metrics (typed) ----
        NULLIF(days_for_shipping_real, '')::NUMERIC       AS days_ship_real,
        NULLIF(days_for_shipment_scheduled, '')::NUMERIC  AS days_ship_sched,
        NULLIF(late_delivery_risk, '')::INT               AS late_delivery_risk,
        TRIM(delivery_status)                             AS delivery_status,
        TRIM(shipping_mode)                               AS shipping_mode,

        -- ---- money / volume (typed) ----
        NULLIF(sales, '')::NUMERIC                        AS sales,
        NULLIF(order_item_total, '')::NUMERIC             AS order_item_total,
        NULLIF(order_item_quantity, '')::NUMERIC          AS quantity,
        NULLIF(order_item_discount, '')::NUMERIC          AS discount,
        NULLIF(order_profit_per_order, '')::NUMERIC       AS profit,
        NULLIF(order_item_product_price, '')::NUMERIC     AS unit_price,

        -- ---- dimensions (harmonised: trim + standard case) ----
        INITCAP(TRIM(customer_segment))                   AS customer_segment,
        INITCAP(TRIM(category_name))                      AS category_name,
        TRIM(product_name)                                AS product_name,
        INITCAP(TRIM(department_name))                    AS department_name,
        UPPER(TRIM(market))                               AS market,
        INITCAP(TRIM(order_region))                       AS order_region,
        INITCAP(TRIM(order_country))                      AS order_country,
        INITCAP(TRIM(order_city))                         AS order_city,
        TRIM(order_status)                                AS order_status,

        -- ---- de-dup helper: one row per order_item_id ----
        ROW_NUMBER() OVER (
            PARTITION BY NULLIF(order_item_id, '')::INT
            ORDER BY shipping_date_dateorders DESC NULLS LAST
        ) AS rn
    FROM bronze.orders_raw
    WHERE order_id IS NOT NULL AND order_id <> ''        -- drop rows w/o a key
)
SELECT
    order_id,
    order_item_id,
    customer_id,
    product_id,
    category_id,
    order_date,
    shipping_date,
    days_ship_real,
    days_ship_sched,
    late_delivery_risk,
    delivery_status,
    shipping_mode,
    sales,
    order_item_total,
    quantity,
    discount,
    profit,
    unit_price,
    customer_segment,
    category_name,
    product_name,
    department_name,
    market,
    order_region,
    order_country,
    order_city,
    order_status,

    -- ---- DERIVED COLUMNS (business logic) ----
    GREATEST(shipping_date - order_date, 0)               AS delivery_days,
    CASE
        WHEN days_ship_real > days_ship_sched THEN TRUE
        ELSE FALSE
    END                                                   AS is_late,
    CASE
        WHEN order_item_total > 0
        THEN ROUND(profit / order_item_total, 4)
        ELSE 0
    END                                                   AS profit_margin
FROM typed
WHERE rn = 1                                              -- keep one row per item (de-dup)
  AND order_date IS NOT NULL
  AND sales IS NOT NULL;

    
    
    
SELECT COUNT(*) AS silver_rows FROM silver.orders_clean;
SELECT order_id, order_date, sales, profit, is_late, order_region
FROM silver.orders_clean LIMIT 5;--------
-- DATA QUALITY CHECKS (record results in docs/data_quality_notes.md)
-- ------------------------------------------------------------
-- SELECT COUNT(*) AS clean_rows FROM silver.orders_clean;
-- SELECT COUNT(*) AS dupes_removed
--   FROM bronze.orders_raw - (SELECT COUNT(*) FROM silver.orders_clean);  -- conceptual
-- SELECT MIN(order_date), MAX(order_date) FROM silver.orders_clean;
-- SELECT delivery_status, COUNT(*) FROM silver.orders_clean GROUP BY 1 ORDER BY 2 DESC;
-- SELECT ROUND(AVG(CASE WHEN is_late THEN 1 ELSE 0 END)*100,1) AS late_pct FROM silver.orders_clean;
