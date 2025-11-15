-- Model that skips cost checking
{{ config(
    materialized='table',
    meta={
        'cost_guard_skip': true
    }
) }}

SELECT
    id,
    name,
    category,
    brand,
    price,
    cost,
    inventory_count
FROM {{ source('raw', 'products') }}
WHERE is_active = TRUE

