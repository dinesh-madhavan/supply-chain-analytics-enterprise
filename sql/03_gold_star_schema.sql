-- ============================================================
-- 03_GOLD_STAR_SCHEMA.sql
-- Layer: GOLD (business-ready Kimball star schema)
-- Engine: PostgreSQL
-- Input:  silver.orders_clean
-- Output: gold.fact_sales + gold.dim_customers / dim_products /
--         dim_geography / dim_date
-- ------------------------------------------------------------
-- Star schema with SURROGATE KEYS (integer) — the prerequisite
-- pattern for an enterprise Power BI semantic model.
--
--                       gold.dim_date
--                            |
--   gold.dim_customers --- gold.fact_sales --- gold.dim_products
--                            |
--                       gold.dim_geography
-- ============================================================

DROP SCHEMA IF EXISTS gold CASCADE;
CREATE SCHEMA gold;

-- ------------------------------------------------------------
-- DIM_CUSTOMERS (surrogate key = customer_key)
-- ------------------------------------------------------------
CREATE TABLE gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id)  AS customer_key,
    customer_id,
    customer_segment
FROM (SELECT DISTINCT customer_id, customer_segment FROM silver.orders_clean) c;

ALTER TABLE gold.dim_customers ADD PRIMARY KEY (customer_key);

-- ------------------------------------------------------------
-- DIM_PRODUCTS
-- ------------------------------------------------------------
CREATE TABLE gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY product_id)   AS product_key,
    product_id,
    product_name,
    category_name,
    department_name
FROM (SELECT DISTINCT product_id, product_name, category_name, department_name
      FROM silver.orders_clean) p;

ALTER TABLE gold.dim_products ADD PRIMARY KEY (product_key);

-- ------------------------------------------------------------
-- DIM_GEOGRAPHY
-- ------------------------------------------------------------
CREATE TABLE gold.dim_geography AS
SELECT
    ROW_NUMBER() OVER (ORDER BY market, order_region, order_country) AS geo_key,
    market,
    order_region,
    order_country
FROM (SELECT DISTINCT market, order_region, order_country FROM silver.orders_clean) g;

ALTER TABLE gold.dim_geography ADD PRIMARY KEY (geo_key);

-- ------------------------------------------------------------
-- DIM_DATE (generated calendar covering the data range)
-- ------------------------------------------------------------
CREATE TABLE gold.dim_date AS
WITH bounds AS (
    SELECT MIN(order_date) AS d0, MAX(order_date) AS d1 FROM silver.orders_clean
),
cal AS (
    SELECT generate_series(d0, d1, INTERVAL '1 day')::DATE AS dt FROM bounds
)
SELECT
    TO_CHAR(dt, 'YYYYMMDD')::INT       AS date_key,
    dt                                  AS full_date,
    EXTRACT(YEAR FROM dt)::INT          AS year,
    EXTRACT(QUARTER FROM dt)::INT       AS quarter,
    EXTRACT(MONTH FROM dt)::INT         AS month,
    TO_CHAR(dt, 'Mon')                  AS month_name,
    EXTRACT(WEEK FROM dt)::INT          AS week,
    TO_CHAR(dt, 'Dy')                   AS day_name,
    CASE WHEN EXTRACT(ISODOW FROM dt) IN (6,7) THEN TRUE ELSE FALSE END AS is_weekend
FROM cal;

ALTER TABLE gold.dim_date ADD PRIMARY KEY (date_key);

-- ------------------------------------------------------------
-- FACT_SALES (grain = one order line item)
-- Foreign keys to every dim + additive measures only.
-- ------------------------------------------------------------
CREATE TABLE gold.fact_sales AS
SELECT
    s.order_item_id,
    s.order_id,
    dc.customer_key,
    dp.product_key,
    dg.geo_key,
    TO_CHAR(s.order_date, 'YYYYMMDD')::INT  AS date_key,
    -- measures
    s.quantity,
    s.sales,
    s.order_item_total,
    s.discount,
    s.profit,
    s.profit_margin,
    s.delivery_days,
    s.days_ship_real,
    s.days_ship_sched,
    s.late_delivery_risk,
    s.is_late,
    s.delivery_status,
    s.shipping_mode
FROM silver.orders_clean s
LEFT JOIN gold.dim_customers dc ON dc.customer_id = s.customer_id
                               AND dc.customer_segment = s.customer_segment
LEFT JOIN gold.dim_products  dp ON dp.product_id = s.product_id
                               AND dp.product_name = s.product_name
LEFT JOIN gold.dim_geography dg ON dg.market = s.market
                               AND dg.order_region = s.order_region
                               AND dg.order_country = s.order_country;

ALTER TABLE gold.fact_sales ADD PRIMARY KEY (order_item_id);

-- Indexes for join/filter performance (enterprise habit)
CREATE INDEX idx_fact_customer ON gold.fact_sales(customer_key);
CREATE INDEX idx_fact_product  ON gold.fact_sales(product_key);
CREATE INDEX idx_fact_geo      ON gold.fact_sales(geo_key);
CREATE INDEX idx_fact_date     ON gold.fact_sales(date_key);

-- ------------------------------------------------------------
-- VALIDATION
-- ------------------------------------------------------------
-- SELECT COUNT(*) FROM gold.fact_sales;                 -- ~ rows in silver
-- SELECT COUNT(*) FROM gold.fact_sales WHERE customer_key IS NULL;  -- expect 0
-- SELECT COUNT(*) FROM gold.fact_sales WHERE product_key  IS NULL;  -- expect 0
-- SELECT COUNT(*) FROM gold.dim_date;                   -- days in range
