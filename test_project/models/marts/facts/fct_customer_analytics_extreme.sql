{{
  config(
    materialized='table',
    tags=['marts', 'aggregates', 'cross_database', 'extreme_cost'],
    meta={
      'cost_guard_skip': false,
      'warning': 'This model is intentionally expensive for testing'
    }
  )
}}

-- EXTREMELY EXPENSIVE MODEL - Kitchen sink of expensive operations
-- Purpose: Test cost guard with worst-case scenario
-- Expected cost: EXTREME (should trigger warnings)

WITH customer_360 AS (
    -- Get all customer data with complex aggregations
    SELECT
        c.customer_id,
        c.customer_segment,
        c.country,
        COUNT(DISTINCT o.order_id) as order_count,
        SUM(o.total_amount) as total_spent,
        AVG(o.total_amount) as avg_order_value,
        STDDEV(o.total_amount) as order_value_stddev,
        MIN(o.order_date) as first_order_date,
        MAX(o.order_date) as last_order_date
    FROM {{ ref('stg_sales__customers') }} c
    LEFT JOIN {{ ref('stg_sales__orders') }} o ON c.customer_id = o.customer_id
    GROUP BY 1, 2, 3
),

product_affinity AS (
    -- Complex self-join to find products purchased together
    SELECT
        oi1.product_id as product_a,
        oi2.product_id as product_b,
        COUNT(DISTINCT oi1.order_id) as times_purchased_together,
        AVG(oi1.line_total + oi2.line_total) as avg_combined_value
    FROM {{ ref('stg_sales__order_items') }} oi1
    INNER JOIN {{ ref('stg_sales__order_items') }} oi2
        ON oi1.order_id = oi2.order_id
        AND oi1.product_id < oi2.product_id
    GROUP BY 1, 2
    HAVING COUNT(DISTINCT oi1.order_id) >= 5
),

web_journey AS (
    -- Sessionization with path analysis
    SELECT
        we.customer_id,
        we.session_id,
        LISTAGG(we.event_type, ' -> ') WITHIN GROUP (ORDER BY we.event_timestamp) as event_path,
        COUNT(*) as events_in_session,
        DATEDIFF(second, MIN(we.event_timestamp), MAX(we.event_timestamp)) as session_duration,
        MAX(CASE WHEN we.event_type = 'purchase' THEN 1 ELSE 0 END) as converted
    FROM {{ ref('stg_analytics__web_events') }} we
    GROUP BY 1, 2
),

cohort_analysis AS (
    -- Cohort retention analysis
    SELECT
        c.customer_id,
        DATE_TRUNC('month', c.signup_date) as cohort_month,
        DATE_TRUNC('month', o.order_date) as order_month,
        DATEDIFF(month, DATE_TRUNC('month', c.signup_date), DATE_TRUNC('month', o.order_date)) as months_since_signup
    FROM {{ ref('stg_sales__customers') }} c
    INNER JOIN {{ ref('stg_sales__orders') }} o ON c.customer_id = o.customer_id
    WHERE o.is_completed = TRUE
),

geographic_clusters AS (
    -- Geographic clustering with multiple aggregations
    SELECT
        g.region,
        g.country,
        COUNT(DISTINCT c.customer_id) as customer_count,
        SUM(c.lifetime_value) as total_ltv,
        AVG(c.lifetime_value) as avg_ltv,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.lifetime_value) as median_ltv,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY c.lifetime_value) as p75_ltv,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY c.lifetime_value) as p90_ltv
    FROM {{ ref('stg_reference__geography') }} g
    INNER JOIN {{ ref('stg_sales__customers') }} c
        ON g.country = c.country
        AND g.state = c.state
        AND g.city = c.city
    GROUP BY 1, 2
)

-- Final join of all CTEs with window functions
SELECT
    c360.customer_id,
    c360.customer_segment,
    c360.country,
    c360.order_count,
    c360.total_spent,
    c360.avg_order_value,
    c360.order_value_stddev,
    
    -- Web journey metrics
    COUNT(DISTINCT wj.session_id) as total_sessions,
    AVG(wj.events_in_session) as avg_events_per_session,
    AVG(wj.session_duration) as avg_session_duration,
    SUM(wj.converted) as converted_sessions,
    
    -- Cohort metrics
    COUNT(DISTINCT ca.order_month) as active_months,
    MAX(ca.months_since_signup) as customer_age_months,
    
    -- Geographic context
    gc.total_ltv as region_total_ltv,
    gc.avg_ltv as region_avg_ltv,
    gc.customer_count as region_customer_count,
    
    -- Complex window functions
    ROW_NUMBER() OVER (PARTITION BY c360.customer_segment ORDER BY c360.total_spent DESC) as segment_rank,
    PERCENT_RANK() OVER (PARTITION BY c360.country ORDER BY c360.total_spent) as country_percentile,
    NTILE(10) OVER (ORDER BY c360.total_spent) as value_decile,
    
    -- Moving averages
    AVG(c360.avg_order_value) OVER (
        PARTITION BY c360.customer_segment 
        ORDER BY c360.first_order_date 
        ROWS BETWEEN 100 PRECEDING AND CURRENT ROW
    ) as segment_moving_avg_order_value,
    
    CURRENT_TIMESTAMP() as created_at

FROM customer_360 c360
LEFT JOIN web_journey wj ON c360.customer_id = wj.customer_id
LEFT JOIN cohort_analysis ca ON c360.customer_id = ca.customer_id
LEFT JOIN geographic_clusters gc 
    ON c360.country = gc.country
WHERE c360.order_count > 0
GROUP BY 
    c360.customer_id, c360.customer_segment, c360.country,
    c360.order_count, c360.total_spent, c360.avg_order_value, c360.order_value_stddev,
    c360.first_order_date, gc.total_ltv, gc.avg_ltv, gc.customer_count

