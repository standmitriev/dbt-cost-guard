-- VERY HIGH complexity model with window functions and multiple joins
-- Intentionally complex to demonstrate cost warnings
{{ config(
    materialized='table',
    tags=['expensive', 'high_cost']
) }}

WITH order_details AS (
    SELECT
        o.id as order_id,
        o.user_id,
        o.order_date,
        o.status,
        o.total_amount,
        oi.id as order_item_id,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.quantity * oi.unit_price as item_total
    FROM {{ ref('stg_orders') }} o
    INNER JOIN {{ source('raw', 'order_items') }} oi
        ON o.id = oi.order_id
),

product_info AS (
    SELECT
        p.id as product_id,
        p.name as product_name,
        p.category,
        p.brand,
        p.cost as product_cost,
        p.price as product_price
    FROM {{ source('raw', 'products') }} p
),

enriched_items AS (
    SELECT
        od.*,
        pi.product_name,
        pi.category,
        pi.brand,
        pi.product_cost,
        pi.product_price,
        od.item_total - (od.quantity * pi.product_cost) as item_profit
    FROM order_details od
    LEFT JOIN product_info pi
        ON od.product_id = pi.product_id
),

-- Add expensive window functions for analytics
items_with_ranking AS (
    SELECT
        *,
        -- Multiple window functions increase computation cost
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY item_total DESC) as item_rank_in_order,
        RANK() OVER (PARTITION BY category ORDER BY item_total DESC) as category_rank,
        DENSE_RANK() OVER (PARTITION BY brand ORDER BY item_profit DESC) as brand_profit_rank,
        
        -- Running totals (expensive!)
        SUM(item_total) OVER (PARTITION BY user_id ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_user_total,
        SUM(item_profit) OVER (PARTITION BY user_id ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_user_profit,
        
        -- Moving averages (very expensive!)
        AVG(item_total) OVER (PARTITION BY category ORDER BY order_date ROWS BETWEEN 30 PRECEDING AND CURRENT ROW) as category_30d_avg,
        AVG(item_profit) OVER (PARTITION BY brand ORDER BY order_date ROWS BETWEEN 90 PRECEDING AND CURRENT ROW) as brand_90d_avg_profit,
        AVG(quantity) OVER (PARTITION BY product_id ORDER BY order_date ROWS BETWEEN 7 PRECEDING AND CURRENT ROW) as product_7d_avg_qty,
        
        -- LAG/LEAD functions
        LAG(order_date, 1) OVER (PARTITION BY user_id ORDER BY order_date) as previous_order_date,
        LAG(item_total, 1) OVER (PARTITION BY user_id ORDER BY order_date) as previous_item_total,
        LEAD(order_date, 1) OVER (PARTITION BY user_id ORDER BY order_date) as next_order_date,
        LEAD(item_total, 1) OVER (PARTITION BY user_id ORDER BY order_date) as next_item_total,
        
        -- Global ranking (MOST expensive - sorts entire dataset!)
        PERCENT_RANK() OVER (ORDER BY item_profit DESC) as profit_percentile,
        NTILE(100) OVER (ORDER BY item_total DESC) as revenue_bucket
    FROM enriched_items
),

-- Add more aggregations for complexity
category_stats AS (
    SELECT
        category,
        brand,
        COUNT(DISTINCT order_id) as category_brand_orders,
        SUM(item_total) as category_brand_revenue,
        AVG(item_profit) as category_brand_avg_profit
    FROM enriched_items
    GROUP BY category, brand
)

-- Final join with aggregated stats
SELECT
    iwr.order_item_id,
    iwr.order_id,
    iwr.user_id,
    iwr.order_date,
    iwr.status,
    iwr.product_id,
    iwr.product_name,
    iwr.category,
    iwr.brand,
    iwr.quantity,
    iwr.unit_price,
    iwr.item_total,
    iwr.product_cost,
    iwr.product_price,
    iwr.item_profit,
    
    -- Rankings
    iwr.item_rank_in_order,
    iwr.category_rank,
    iwr.brand_profit_rank,
    iwr.profit_percentile,
    iwr.revenue_bucket,
    
    -- Running totals
    iwr.running_user_total,
    iwr.running_user_profit,
    
    -- Moving averages
    iwr.category_30d_avg,
    iwr.brand_90d_avg_profit,
    iwr.product_7d_avg_qty,
    
    -- Time differences
    iwr.previous_order_date,
    iwr.next_order_date,
    DATEDIFF(day, iwr.previous_order_date, iwr.order_date) as days_since_last_order,
    DATEDIFF(day, iwr.order_date, iwr.next_order_date) as days_until_next_order,
    
    -- Category/brand stats (from join)
    cs.category_brand_orders,
    cs.category_brand_revenue,
    cs.category_brand_avg_profit,
    
    -- Additional computed metrics
    CASE
        WHEN iwr.profit_percentile >= 0.99 THEN 'Top 1%'
        WHEN iwr.profit_percentile >= 0.95 THEN 'Top 5%'
        WHEN iwr.profit_percentile >= 0.90 THEN 'Top 10%'
        ELSE 'Standard'
    END as profit_tier,
    
    -- Variance from averages
    CASE
        WHEN iwr.category_30d_avg > 0 THEN (iwr.item_total - iwr.category_30d_avg) / iwr.category_30d_avg * 100
        ELSE NULL
    END as pct_vs_category_avg,
    
    CASE
        WHEN iwr.previous_item_total > 0 THEN (iwr.item_total - iwr.previous_item_total) / iwr.previous_item_total * 100
        ELSE NULL
    END as pct_vs_previous_purchase
    
FROM items_with_ranking iwr
LEFT JOIN category_stats cs
    ON iwr.category = cs.category
    AND iwr.brand = cs.brand

