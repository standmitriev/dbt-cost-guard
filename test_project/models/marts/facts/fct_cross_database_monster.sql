-- 🔥 INSANELY EXPENSIVE MODEL - CROSS-DATABASE AGGREGATION NIGHTMARE! 🔥
-- Joins ALL databases with minimal filtering and tons of aggregations
-- DO NOT RUN IN PRODUCTION!

{{ config(
    materialized='table',
    tags=['extremely_expensive', 'test_only', 'cross_database']
) }}

WITH all_customers AS (
    SELECT * FROM {{ ref('stg_sales__customers') }}
),

all_orders AS (
    SELECT * FROM {{ ref('stg_sales__orders') }}
),

all_order_items AS (
    SELECT * FROM {{ ref('stg_sales__order_items') }}
),

all_web_events AS (
    SELECT * FROM {{ ref('stg_analytics__web_events') }}
),

all_geography AS (
    SELECT * FROM {{ ref('stg_reference__geography') }}
),

-- 🔥 CROSS-DATABASE JOIN 1: SALES × ANALYTICS (50K × 1M = 50B potential)
sales_and_web AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.signup_date,
        o.order_id,
        o.order_date,
        o.total_amount,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        we.event_id,
        we.event_timestamp,
        we.event_type,
        we.page_url,
        g.country,
        g.city,
        g.region
    FROM all_customers c
    INNER JOIN all_orders o 
        ON c.customer_id = o.customer_id
    INNER JOIN all_order_items oi
        ON o.order_id = oi.order_id
    LEFT JOIN all_web_events we
        ON c.customer_id = we.user_id
        -- 🔥 Very loose join condition = massive explosion
        AND we.event_timestamp >= DATEADD(day, -7, o.order_date)
        AND we.event_timestamp <= DATEADD(day, 7, o.order_date)
    LEFT JOIN all_geography g
        ON c.customer_id = g.geo_id  -- 🔥 Nonsensical join for testing
),

-- 🔥 CRAZY AGGREGATIONS on the exploded dataset
crazy_aggregations AS (
    SELECT
        customer_id,
        order_id,
        product_id,
        country,
        city,
        COUNT(DISTINCT event_id) as event_count,
        COUNT(DISTINCT event_type) as event_type_count,
        COUNT(DISTINCT page_url) as page_count,
        SUM(quantity) as total_quantity,
        SUM(unit_price * quantity) as total_revenue,
        AVG(unit_price) as avg_price,
        MAX(unit_price) as max_price,
        MIN(unit_price) as min_price,
        STDDEV(unit_price) as price_stddev,
        VAR_POP(unit_price) as price_variance,
        -- 🔥 GROUP BY with multiple dimensions = tons of groups
        COUNT(*) as row_count,
        SUM(total_amount) as order_total,
        AVG(total_amount) as avg_order,
        LISTAGG(DISTINCT event_type, ',') WITHIN GROUP (ORDER BY event_type) as event_types
    FROM sales_and_web
    GROUP BY 
        customer_id,
        order_id,
        product_id,
        country,
        city
),

-- 🔥 30+ WINDOW FUNCTIONS on the aggregated data
window_madness AS (
    SELECT
        ca.*,
        -- Ranking functions
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_revenue DESC) as revenue_rank,
        DENSE_RANK() OVER (PARTITION BY product_id ORDER BY total_quantity DESC) as quantity_rank,
        RANK() OVER (PARTITION BY country ORDER BY order_total DESC) as country_rank,
        PERCENT_RANK() OVER (PARTITION BY city ORDER BY total_revenue) as city_percentile,
        NTILE(100) OVER (ORDER BY total_revenue DESC) as revenue_bucket,
        NTILE(50) OVER (PARTITION BY country ORDER BY total_revenue DESC) as country_bucket,
        
        -- LAG/LEAD functions (multiple offsets)
        LAG(total_revenue, 1) OVER (PARTITION BY customer_id ORDER BY order_id) as prev_revenue_1,
        LAG(total_revenue, 2) OVER (PARTITION BY customer_id ORDER BY order_id) as prev_revenue_2,
        LAG(total_revenue, 3) OVER (PARTITION BY customer_id ORDER BY order_id) as prev_revenue_3,
        LAG(total_revenue, 5) OVER (PARTITION BY customer_id ORDER BY order_id) as prev_revenue_5,
        LEAD(total_revenue, 1) OVER (PARTITION BY customer_id ORDER BY order_id) as next_revenue_1,
        LEAD(total_revenue, 2) OVER (PARTITION BY customer_id ORDER BY order_id) as next_revenue_2,
        LEAD(total_revenue, 3) OVER (PARTITION BY customer_id ORDER BY order_id) as next_revenue_3,
        
        -- Running aggregations
        SUM(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_revenue,
        SUM(total_quantity) OVER (PARTITION BY product_id ORDER BY order_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_quantity,
        AVG(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_avg_revenue,
        
        -- Rolling windows (expensive!)
        AVG(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) as rolling_avg_10,
        AVG(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN 30 PRECEDING AND CURRENT ROW) as rolling_avg_30,
        AVG(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN 90 PRECEDING AND CURRENT ROW) as rolling_avg_90,
        AVG(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN 180 PRECEDING AND CURRENT ROW) as rolling_avg_180,
        
        MAX(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN 30 PRECEDING AND CURRENT ROW) as rolling_max_30,
        MIN(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN 30 PRECEDING AND CURRENT ROW) as rolling_min_30,
        
        STDDEV(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN 50 PRECEDING AND CURRENT ROW) as rolling_stddev_50,
        VAR_POP(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN 50 PRECEDING AND CURRENT ROW) as rolling_var_50,
        
        -- Global aggregations (most expensive!)
        PERCENT_RANK() OVER (ORDER BY total_revenue DESC) as global_revenue_percentile,
        CUME_DIST() OVER (ORDER BY total_revenue) as global_cumulative_dist,
        
        -- First/Last values
        FIRST_VALUE(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as first_revenue,
        LAST_VALUE(total_revenue) OVER (PARTITION BY customer_id ORDER BY order_id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as last_revenue,
        
        -- Count aggregations
        COUNT(*) OVER (PARTITION BY customer_id) as customer_order_count,
        COUNT(*) OVER (PARTITION BY product_id) as product_order_count,
        COUNT(*) OVER (PARTITION BY country) as country_order_count
    FROM crazy_aggregations
),

-- 🔥 FINAL EXPLOSION: Self-join on the window results
final_madness AS (
    SELECT
        wm1.*,
        wm2.revenue_rank as related_revenue_rank,
        wm2.total_revenue as related_revenue,
        wm2.country as related_country,
        -- Calculate differences
        wm1.total_revenue - wm2.total_revenue as revenue_diff,
        wm1.revenue_rank - wm2.revenue_rank as rank_diff
    FROM window_madness wm1
    LEFT JOIN window_madness wm2
        ON wm1.customer_id = wm2.customer_id
        AND wm2.revenue_rank = wm1.revenue_rank + 1  -- Next ranked order
)

SELECT * FROM final_madness
WHERE revenue_rank <= 10  -- Limit output but process EVERYTHING first

