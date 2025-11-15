-- Simple staging model - low cost
{{ config(
    materialized='view'
) }}

SELECT
    id,
    user_id,
    order_date,
    status,
    total_amount,
    created_at
FROM {{ source('raw', 'orders') }}
WHERE deleted_at IS NULL

