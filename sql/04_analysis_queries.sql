-- ============================================================
-- 04_ANALYSIS_QUERIES.sql
-- Layer: GOLD analysis — answers the business questions directly in SQL.
-- These double as (a) EDA, (b) interview talking points, (c) a sanity
-- check that your Power BI DAX produces the same numbers.
-- ============================================================

-- Q1. Revenue & profit by region -----------------------------
SELECT g.order_region,
       ROUND(SUM(f.sales),0)                 AS total_sales,
       ROUND(SUM(f.profit),0)                AS total_profit,
       ROUND(AVG(f.profit_margin)*100,1)     AS avg_margin_pct
FROM gold.fact_sales f
JOIN gold.dim_geography g ON g.geo_key = f.geo_key
GROUP BY g.order_region
ORDER BY total_sales DESC;

-- Q2. On-time delivery rate by region (the supply-chain KPI) --
SELECT g.order_region,
       COUNT(*)                                                        AS orders,
       ROUND(AVG(CASE WHEN f.is_late THEN 0 ELSE 1 END)*100,1)         AS on_time_pct,
       ROUND(AVG(f.late_delivery_risk)*100,1)                          AS late_risk_pct
FROM gold.fact_sales f
JOIN gold.dim_geography g ON g.geo_key = f.geo_key
GROUP BY g.order_region
ORDER BY on_time_pct ASC;        -- worst performers first

-- Q3. Top 10 products by profit ------------------------------
SELECT p.product_name, p.category_name,
       ROUND(SUM(f.profit),0)   AS total_profit,
       SUM(f.quantity)          AS units
FROM gold.fact_sales f
JOIN gold.dim_products p ON p.product_key = f.product_key
GROUP BY p.product_name, p.category_name
ORDER BY total_profit DESC
LIMIT 10;

-- Q4. Customer segment value ---------------------------------
SELECT c.customer_segment,
       COUNT(DISTINCT f.order_id)         AS orders,
       ROUND(SUM(f.sales),0)              AS total_sales,
       ROUND(SUM(f.sales)/COUNT(DISTINCT f.order_id),2) AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_customers c ON c.customer_key = f.customer_key
GROUP BY c.customer_segment
ORDER BY total_sales DESC;

-- Q5. Monthly sales trend (time series for the line chart) ---
SELECT d.year, d.month, d.month_name,
       ROUND(SUM(f.sales),0)  AS monthly_sales
FROM gold.fact_sales f
JOIN gold.dim_date d ON d.date_key = f.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;

-- Q6. Shipping mode vs lateness (root-cause angle) -----------
SELECT f.shipping_mode,
       COUNT(*)                                                AS orders,
       ROUND(AVG(f.delivery_days),1)                           AS avg_delivery_days,
       ROUND(AVG(CASE WHEN f.is_late THEN 1 ELSE 0 END)*100,1) AS late_pct
FROM gold.fact_sales f
GROUP BY f.shipping_mode
ORDER BY late_pct DESC;

-- Q7. Running 3-month avg sales (window function showcase) ---
WITH monthly AS (
    SELECT d.year, d.month, SUM(f.sales) AS sales
    FROM gold.fact_sales f
    JOIN gold.dim_date d ON d.date_key = f.date_key
    GROUP BY d.year, d.month
)
SELECT year, month, ROUND(sales,0) AS sales,
       ROUND(AVG(sales) OVER (ORDER BY year, month
                              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),0) AS sales_3mo_avg
FROM monthly
ORDER BY year, month;
