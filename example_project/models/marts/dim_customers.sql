-- Medium complexity model with aggregations
{{ config(
    materialized='table'
) }}

WITH user_orders AS (
    SELECT
        u.id as user_id,
        u.email,
        u.first_name,
        u.last_name,
        o.id as order_id,
        o.order_date,
        o.status,
        o.total_amount
    FROM {{ ref('stg_users') }} u
    LEFT JOIN {{ ref('stg_orders') }} o
        ON u.id = o.user_id
),

user_metrics AS (
    SELECT
        user_id,
        email,
        first_name,
        last_name,
        COUNT(order_id) as total_orders,
        SUM(total_amount) as lifetime_value,
        AVG(total_amount) as avg_order_value,
        MIN(order_date) as first_order_date,
        MAX(order_date) as last_order_date
    FROM user_orders
    GROUP BY 1, 2, 3, 4
)

SELECT
    user_id,
    email,
    first_name,
    last_name,
    total_orders,
    lifetime_value,
    avg_order_value,
    first_order_date,
    last_order_date,
    DATEDIFF(day, first_order_date, last_order_date) as customer_age_days,
    CASE
        WHEN lifetime_value >= 1000 THEN 'VIP'
        WHEN lifetime_value >= 500 THEN 'Premium'
        WHEN lifetime_value >= 100 THEN 'Standard'
        ELSE 'Basic'
    END as customer_segment
FROM user_metrics

