{{
  config(
    materialized='table',
    tags=['marts', 'facts', 'very_high_cost'],
    meta={
      'description': 'Cross-database fact table with multiple complex joins',
      'expected_cost': 'VERY HIGH'
    }
  )
}}

-- VERY EXPENSIVE MODEL - Cross-database joins, window functions, aggregations
-- Joins data from SALES_DB, ANALYTICS_DB, and REFERENCE_DB
-- Expected cost: VERY HIGH ($20+)

WITH order_details AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        o.order_status,
        o.total_amount,
        o.net_amount,
        c.customer_segment,
        c.country,
        c.state,
        c.city,
        c.lifetime_value
    FROM {{ ref('stg_sales__orders') }} o
    INNER JOIN {{ ref('stg_sales__customers') }} c
        ON o.customer_id = c.customer_id
    WHERE o.is_completed = TRUE
),

order_line_items AS (
    SELECT
        oi.order_id,
        COUNT(*) as item_count,
        SUM(oi.quantity) as total_quantity,
        SUM(oi.line_total) as total_line_amount,
        LISTAGG(DISTINCT oi.category, ', ') as categories,
        COUNT(DISTINCT oi.product_id) as unique_products,
        AVG(oi.unit_price) as avg_unit_price
    FROM {{ ref('stg_sales__order_items') }} oi
    GROUP BY oi.order_id
),

campaign_data AS (
    SELECT
        ca.order_id,
        mc.campaign_name,
        mc.channel,
        ca.attribution_model,
        ca.attribution_percent,
        ROW_NUMBER() OVER (PARTITION BY ca.order_id ORDER BY ca.attribution_percent DESC) as attribution_rank
    FROM {{ source('analytics', 'campaign_attributions') }} ca
    INNER JOIN {{ source('analytics', 'marketing_campaigns') }} mc
        ON ca.campaign_id = mc.campaign_id
),

web_activity AS (
    SELECT
        we.customer_id,
        we.event_date,
        COUNT(*) as total_events,
        COUNT(DISTINCT we.session_id) as total_sessions,
        SUM(CASE WHEN we.is_conversion_event THEN 1 ELSE 0 END) as conversion_events,
        COUNT(DISTINCT we.device_type) as devices_used
    FROM {{ ref('stg_analytics__web_events') }} we
    GROUP BY we.customer_id, we.event_date
),

geo_enrichment AS (
    SELECT
        g.country,
        g.state,
        g.city,
        g.region,
        g.population,
        g.median_income,
        g.city_size,
        AVG(g.population) OVER (PARTITION BY g.region) as avg_region_population
    FROM {{ ref('stg_reference__geography') }} g
)

SELECT
    od.order_id,
    od.customer_id,
    od.order_date,
    od.order_status,
    od.total_amount,
    od.net_amount,
    od.customer_segment,
    od.lifetime_value,
    
    -- Order line metrics
    oli.item_count,
    oli.total_quantity,
    oli.total_line_amount,
    oli.categories,
    oli.unique_products,
    oli.avg_unit_price,
    
    -- Campaign attribution
    cd.campaign_name as primary_campaign,
    cd.channel as primary_channel,
    cd.attribution_model,
    cd.attribution_percent as primary_attribution_percent,
    
    -- Web activity metrics
    wa.total_events as customer_events_on_order_date,
    wa.total_sessions as customer_sessions_on_order_date,
    wa.conversion_events as conversion_events_on_order_date,
    wa.devices_used,
    
    -- Geographic enrichment
    ge.region,
    ge.population as city_population,
    ge.median_income as city_median_income,
    ge.city_size,
    ge.avg_region_population,
    
    -- Derived metrics with window functions
    SUM(od.total_amount) OVER (PARTITION BY od.customer_id ORDER BY od.order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as customer_cumulative_revenue,
    ROW_NUMBER() OVER (PARTITION BY od.customer_id ORDER BY od.order_date) as customer_order_number,
    LAG(od.order_date) OVER (PARTITION BY od.customer_id ORDER BY od.order_date) as previous_order_date,
    DATEDIFF(day, LAG(od.order_date) OVER (PARTITION BY od.customer_id ORDER BY od.order_date), od.order_date) as days_since_last_order,
    AVG(od.total_amount) OVER (PARTITION BY od.customer_segment) as segment_avg_order_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY od.total_amount) OVER (PARTITION BY ge.region) as region_median_order_value,
    
    CURRENT_TIMESTAMP() as created_at

FROM order_details od
LEFT JOIN order_line_items oli
    ON od.order_id = oli.order_id
LEFT JOIN campaign_data cd
    ON od.order_id = cd.order_id
    AND cd.attribution_rank = 1
LEFT JOIN web_activity wa
    ON od.customer_id = wa.customer_id
    AND od.order_date = wa.event_date
LEFT JOIN geo_enrichment ge
    ON od.country = ge.country
    AND od.state = ge.state
    AND od.city = ge.city

