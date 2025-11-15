{{
  config(
    materialized='table',
    tags=['marts', 'dimensions', 'medium_cost']
  )
}}

-- Customer dimension with SCD Type 2 attributes
-- Expected cost: MEDIUM (multiple aggregations and joins)

WITH customer_base AS (
    SELECT
        c.customer_id,
        c.email,
        c.first_name,
        c.last_name,
        c.country,
        c.state,
        c.city,
        c.signup_date,
        c.customer_segment,
        c.lifetime_value,
        c.is_active
    FROM {{ ref('stg_sales__customers') }} c
),

customer_orders AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) as total_orders,
        SUM(o.net_amount) as total_revenue,
        AVG(o.net_amount) as avg_order_value,
        MIN(o.order_date) as first_order_date,
        MAX(o.order_date) as last_order_date,
        DATEDIFF(day, MIN(o.order_date), MAX(o.order_date)) as customer_tenure_days
    FROM {{ ref('stg_sales__orders') }} o
    WHERE o.is_completed = TRUE
    GROUP BY o.customer_id
),

customer_web_behavior AS (
    SELECT
        we.customer_id,
        COUNT(*) as total_web_events,
        COUNT(DISTINCT we.session_id) as total_sessions,
        COUNT(DISTINCT DATE(we.event_timestamp)) as active_days,
        SUM(CASE WHEN we.is_conversion_event THEN 1 ELSE 0 END) as total_conversion_events,
        MODE(we.device_type) as preferred_device,
        MODE(we.browser) as preferred_browser
    FROM {{ ref('stg_analytics__web_events') }} we
    GROUP BY we.customer_id
),

geographic_context AS (
    SELECT
        g.country,
        g.state,
        g.city,
        g.region,
        g.city_size,
        g.population,
        g.median_income
    FROM {{ ref('stg_reference__geography') }} g
)

SELECT
    cb.customer_id,
    cb.email,
    cb.first_name,
    cb.last_name,
    cb.country,
    cb.state,
    cb.city,
    cb.signup_date,
    cb.customer_segment,
    cb.lifetime_value,
    cb.is_active,
    
    -- Order metrics
    COALESCE(co.total_orders, 0) as total_orders,
    COALESCE(co.total_revenue, 0) as total_revenue,
    COALESCE(co.avg_order_value, 0) as avg_order_value,
    co.first_order_date,
    co.last_order_date,
    COALESCE(co.customer_tenure_days, 0) as customer_tenure_days,
    
    -- Web behavior metrics
    COALESCE(cw.total_web_events, 0) as total_web_events,
    COALESCE(cw.total_sessions, 0) as total_sessions,
    COALESCE(cw.active_days, 0) as active_days,
    COALESCE(cw.total_conversion_events, 0) as total_conversion_events,
    cw.preferred_device,
    cw.preferred_browser,
    
    -- Geographic context
    gc.region,
    gc.city_size,
    gc.population as city_population,
    gc.median_income as city_median_income,
    
    -- Derived customer segments
    CASE
        WHEN co.total_orders >= 10 AND co.total_revenue > 5000 THEN 'VIP'
        WHEN co.total_orders >= 5 THEN 'Loyal'
        WHEN co.total_orders >= 2 THEN 'Repeat'
        WHEN co.total_orders = 1 THEN 'One-time'
        ELSE 'Prospect'
    END as customer_lifecycle_stage,
    
    CASE
        WHEN co.last_order_date >= DATEADD(day, -30, CURRENT_DATE()) THEN 'Active'
        WHEN co.last_order_date >= DATEADD(day, -90, CURRENT_DATE()) THEN 'At Risk'
        WHEN co.last_order_date >= DATEADD(day, -180, CURRENT_DATE()) THEN 'Dormant'
        WHEN co.last_order_date IS NOT NULL THEN 'Churned'
        ELSE 'Never Purchased'
    END as customer_status,
    
    CURRENT_TIMESTAMP() as created_at

FROM customer_base cb
LEFT JOIN customer_orders co
    ON cb.customer_id = co.customer_id
LEFT JOIN customer_web_behavior cw
    ON cb.customer_id = cw.customer_id
LEFT JOIN geographic_context gc
    ON cb.country = gc.country
    AND cb.state = gc.state
    AND cb.city = gc.city

