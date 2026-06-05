-- ============================================================
-- 01_BRONZE_LOAD.sql  (no-Python version — pure psql)
-- Layer: BRONZE (raw landing — load exactly as it arrived, no cleaning)
-- Engine: PostgreSQL
-- ------------------------------------------------------------
-- HOW TO RUN (from Terminal, NOT inside DBeaver, because \copy is a
-- psql client command):
--
--   psql supplychain -f sql/01_bronze_load.sql
--
-- BRONZE RULE: everything lands as TEXT. No casting/cleaning here.
-- ============================================================

DROP SCHEMA IF EXISTS bronze CASCADE;
CREATE SCHEMA bronze;

-- Raw table: all 53 columns TEXT so a dirty CSV never fails the load.
CREATE TABLE bronze.orders_raw (
    type                          TEXT,
    days_for_shipping_real        TEXT,
    days_for_shipment_scheduled   TEXT,
    benefit_per_order             TEXT,
    sales_per_customer            TEXT,
    delivery_status               TEXT,
    late_delivery_risk            TEXT,
    category_id                   TEXT,
    category_name                 TEXT,
    customer_city                 TEXT,
    customer_country              TEXT,
    customer_email                TEXT,
    customer_fname                TEXT,
    customer_id                   TEXT,
    customer_lname                TEXT,
    customer_password             TEXT,
    customer_segment              TEXT,
    customer_state                TEXT,
    customer_street               TEXT,
    customer_zipcode              TEXT,
    department_id                 TEXT,
    department_name               TEXT,
    latitude                      TEXT,
    longitude                     TEXT,
    market                        TEXT,
    order_city                    TEXT,
    order_country                 TEXT,
    order_customer_id             TEXT,
    order_date_dateorders         TEXT,
    order_id                      TEXT,
    order_item_cardprod_id        TEXT,
    order_item_discount           TEXT,
    order_item_discount_rate      TEXT,
    order_item_id                 TEXT,
    order_item_product_price      TEXT,
    order_item_profit_ratio       TEXT,
    order_item_quantity           TEXT,
    sales                         TEXT,
    order_item_total              TEXT,
    order_profit_per_order        TEXT,
    order_region                  TEXT,
    order_state                   TEXT,
    order_status                  TEXT,
    order_zipcode                 TEXT,
    product_card_id               TEXT,
    product_category_id           TEXT,
    product_description           TEXT,
    product_image                 TEXT,
    product_name                  TEXT,
    product_price                 TEXT,
    product_status                TEXT,
    shipping_date_dateorders      TEXT,
    shipping_mode                 TEXT
);

-- LOAD the CSV from the project data/ folder.
-- \copy runs on the CLIENT (your Mac), reads the local file, streams to the server.
-- HEADER true = skip the first row. ENCODING 'LATIN1' = DataCo is Latin-1.
\copy bronze.orders_raw FROM '/Users/dineshmadhavan/Projects/supply-chain-analytics-enterprise/data/DataCoSupplyChainDataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'LATIN1')

-- Sanity checks
SELECT COUNT(*) AS row_count FROM bronze.orders_raw;
SELECT order_id, order_item_id, sales, order_region FROM bronze.orders_raw LIMIT 5;
