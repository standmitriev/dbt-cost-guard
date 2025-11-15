-- Very expensive model that should trigger warnings
-- This model intentionally has high complexity
{{ config(
    materialized='table',
    tags=['expensive', 'analytics']
) }}

WITH daily_metrics AS (
    SELECT
        DATE_TRUNC('day', order_date) as metric_date,
        category,
        brand,
        COUNT(DISTINCT order_id) as orders,
        COUNT(DISTINCT user_id) as customers,
        COUNT(order_item_id) as items_sold,
        SUM(quantity) as total_quantity,
        SUM(item_total) as revenue,
        SUM(item_profit) as profit,
        AVG(item_total) as avg_item_value
    FROM {{ ref('fct_order_items') }}
    GROUP BY 1, 2, 3
),

rolling_metrics AS (
    SELECT
        *,
        -- 7-day rolling averages
        AVG(revenue) OVER (PARTITION BY category, brand ORDER BY metric_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as revenue_7d_avg,
        AVG(profit) OVER (PARTITION BY category, brand ORDER BY metric_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as profit_7d_avg,
        AVG(orders) OVER (PARTITION BY category, brand ORDER BY metric_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as orders_7d_avg,
        
        -- 30-day rolling averages
        AVG(revenue) OVER (PARTITION BY category, brand ORDER BY metric_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) as revenue_30d_avg,
        AVG(profit) OVER (PARTITION BY category, brand ORDER BY metric_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) as profit_30d_avg,
        
        -- Year-over-year comparison
        LAG(revenue, 365) OVER (PARTITION BY category, brand ORDER BY metric_date) as revenue_yoy,
        LAG(profit, 365) OVER (PARTITION BY category, brand ORDER BY metric_date) as profit_yoy,
        
        -- Cumulative metrics
        SUM(revenue) OVER (PARTITION BY category, brand, DATE_TRUNC('year', metric_date) ORDER BY metric_date) as ytd_revenue,
        SUM(profit) OVER (PARTITION BY category, brand, DATE_TRUNC('year', metric_date) ORDER BY metric_date) as ytd_profit
    FROM daily_metrics
)

SELECT
    metric_date,
    category,
    brand,
    orders,
    customers,
    items_sold,
    total_quantity,
    revenue,
    profit,
    avg_item_value,
    revenue_7d_avg,
    profit_7d_avg,
    orders_7d_avg,
    revenue_30d_avg,
    profit_30d_avg,
    revenue_yoy,
    profit_yoy,
    ytd_revenue,
    ytd_profit,
    
    -- Growth calculations
    CASE
        WHEN revenue_yoy > 0 THEN (revenue - revenue_yoy) / revenue_yoy * 100
        ELSE NULL
    END as revenue_yoy_growth_pct,
    
    CASE
        WHEN profit_yoy > 0 THEN (profit - profit_yoy) / profit_yoy * 100
        ELSE NULL
    END as profit_yoy_growth_pct,
    
    -- Margin calculations
    CASE
        WHEN revenue > 0 THEN profit / revenue * 100
        ELSE 0
    END as profit_margin_pct
    
FROM rolling_metrics

