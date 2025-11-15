-- 🔥 INSANELY EXPENSIVE MODEL - CARTESIAN PRODUCT! 🔥
-- This model intentionally creates a cartesian product for testing cost warnings
-- DO NOT RUN IN PRODUCTION!

{{ config(
    materialized='table',
    tags=['extremely_expensive', 'test_only', 'cartesian_product']
) }}

WITH customers AS (
    SELECT * FROM {{ ref('stg_sales__customers') }}
),

orders AS (
    SELECT * FROM {{ ref('stg_sales__orders') }}
),

products AS (
    SELECT 
        product_id,
        product_name,
        category,
        price
    FROM SALES_DB.RAW.products
),

-- 🔥 CARTESIAN PRODUCT: customers × orders × products
-- 50K customers × 150K orders × 10K products = 75 TRILLION rows!
cartesian_nightmare AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.customer_email,
        c.signup_date,
        o.order_id,
        o.order_date,
        o.total_amount as order_amount,
        p.product_id,
        p.product_name,
        p.category,
        p.price,
        -- Add some calculations to make it even more expensive
        c.customer_id * o.order_id * p.product_id as combined_key,
        DATEDIFF(day, c.signup_date, o.order_date) as days_since_signup
    FROM customers c
    CROSS JOIN orders o  -- 🔥 NO JOIN CONDITION!
    CROSS JOIN products p  -- 🔥 NO JOIN CONDITION!
),

-- Add aggregations on top of the cartesian product
insane_aggregations AS (
    SELECT
        customer_id,
        product_id,
        category,
        COUNT(*) as row_count,
        SUM(order_amount) as total_spend,
        AVG(order_amount) as avg_spend,
        MAX(order_amount) as max_spend,
        MIN(order_amount) as min_spend,
        STDDEV(order_amount) as stddev_spend,
        -- Window functions on the cartesian product
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_amount DESC) as spend_rank,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY total_spend DESC) as category_rank,
        PERCENT_RANK() OVER (ORDER BY total_spend DESC) as spend_percentile,
        LAG(order_amount, 1) OVER (PARTITION BY customer_id ORDER BY order_date) as prev_order,
        LEAD(order_amount, 1) OVER (PARTITION BY customer_id ORDER BY order_date) as next_order,
        SUM(order_amount) OVER (PARTITION BY customer_id ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_total,
        AVG(order_amount) OVER (PARTITION BY category ORDER BY order_date ROWS BETWEEN 90 PRECEDING AND CURRENT ROW) as rolling_90d_avg
    FROM cartesian_nightmare
    GROUP BY 
        customer_id, 
        product_id, 
        category, 
        order_amount, 
        order_date
)

SELECT 
    *,
    -- More window functions for extra expense
    NTILE(100) OVER (ORDER BY total_spend DESC) as spend_bucket,
    CUME_DIST() OVER (ORDER BY total_spend) as cumulative_dist
FROM insane_aggregations
WHERE spend_rank <= 1000  -- Limit output but still process EVERYTHING

