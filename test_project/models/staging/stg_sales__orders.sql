{{
  config(
    materialized='view',
    tags=['staging', 'sales']
  )
}}

-- Orders staging with basic transformations
-- Expected cost: MEDIUM (large table scan)

SELECT
    order_id,
    customer_id,
    order_date,
    order_status,
    total_amount,
    discount_amount,
    tax_amount,
    shipping_cost,
    payment_method,
    total_amount - discount_amount as net_amount,
    CASE 
        WHEN order_status = 'completed' THEN TRUE
        ELSE FALSE
    END as is_completed,
    created_at,
    updated_at
FROM {{ source('sales', 'orders') }}
WHERE order_date >= '2023-01-01'

