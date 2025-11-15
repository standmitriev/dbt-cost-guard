{{
  config(
    materialized='view',
    tags=['staging', 'sales', 'low_cost']
  )
}}

-- Simple staging view from SALES_DB
-- Expected cost: LOW (view, simple select, small table)

SELECT
    customer_id,
    email,
    first_name,
    last_name,
    country,
    state,
    city,
    signup_date,
    customer_segment,
    lifetime_value,
    is_active,
    created_at,
    updated_at
FROM {{ source('sales', 'customers') }}
WHERE is_active = TRUE
  AND signup_date >= '2023-01-01'

