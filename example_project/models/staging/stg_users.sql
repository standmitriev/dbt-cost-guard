-- Simple staging model - low cost
{{ config(
    materialized='view'
) }}

SELECT
    id,
    email,
    first_name,
    last_name,
    created_at,
    updated_at
FROM {{ source('raw', 'users') }}
WHERE deleted_at IS NULL

