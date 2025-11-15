{{
  config(
    materialized='view',
    tags=['staging', 'sales', 'medium_cost']
  )
}}

-- Staging view with JOIN to products
-- Expected cost: MEDIUM (view with join, moderate complexity)

SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity,
    oi.unit_price,
    oi.discount_percent,
    oi.line_total,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,
    oi.created_at
FROM {{ source('sales', 'order_items') }} oi
INNER JOIN {{ source('sales', 'products') }} p
    ON oi.product_id = p.product_id
WHERE p.is_active = TRUE

