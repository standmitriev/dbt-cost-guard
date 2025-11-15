-- Scale up data for more expensive queries
-- This will add much more data to make costs realistic
-- Note: ID columns are limited to 5 digits (max 99,999), so we scale conservatively

USE DATABASE DEMO_DB;
USE SCHEMA RAW;
USE WAREHOUSE COMPUTE_WH;

-- First, truncate and recreate with more data to fit within constraints
-- This approach avoids ID overflow issues

TRUNCATE TABLE users;
TRUNCATE TABLE orders;
TRUNCATE TABLE products;
TRUNCATE TABLE order_items;

-- Create 90K users (close to the 99,999 limit)
INSERT INTO users
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as id,
    'user' || ROW_NUMBER() OVER (ORDER BY SEQ4()) || '@example.com' as email,
    'First' || ROW_NUMBER() OVER (ORDER BY SEQ4()) as first_name,
    'Last' || ROW_NUMBER() OVER (ORDER BY SEQ4()) as last_name,
    DATEADD(day, -UNIFORM(1, 1000, RANDOM()), CURRENT_DATE()) as created_at,
    CURRENT_TIMESTAMP() as updated_at,
    NULL as deleted_at
FROM TABLE(GENERATOR(ROWCOUNT => 90000));

-- Create 95K orders (close to limit)
INSERT INTO orders
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as id,
    UNIFORM(1, 90000, RANDOM()) as user_id,
    DATEADD(day, -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) as order_date,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'pending'
        WHEN 2 THEN 'completed'
        WHEN 3 THEN 'shipped'
        ELSE 'delivered'
    END as status,
    UNIFORM(10, 1000, RANDOM()) as total_amount,
    CURRENT_TIMESTAMP() as created_at,
    NULL as deleted_at
FROM TABLE(GENERATOR(ROWCOUNT => 95000));

-- Create 9K products
INSERT INTO products
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as id,
    'Product ' || ROW_NUMBER() OVER (ORDER BY SEQ4()) as name,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'Electronics'
        WHEN 2 THEN 'Clothing'
        WHEN 3 THEN 'Books'
        WHEN 4 THEN 'Home & Garden'
        ELSE 'Sports'
    END as category,
    'Brand ' || UNIFORM(1, 50, RANDOM()) as brand,
    UNIFORM(10, 500, RANDOM()) as price,
    UNIFORM(5, 300, RANDOM()) as cost,
    UNIFORM(0, 1000, RANDOM()) as inventory_count,
    TRUE as is_active
FROM TABLE(GENERATOR(ROWCOUNT => 9000));

-- Create 99K order_items (maximum we can fit)
INSERT INTO order_items
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as id,
    UNIFORM(1, 95000, RANDOM()) as order_id,
    UNIFORM(1, 9000, RANDOM()) as product_id,
    UNIFORM(1, 5, RANDOM()) as quantity,
    UNIFORM(10, 500, RANDOM()) as unit_price
FROM TABLE(GENERATOR(ROWCOUNT => 99000));

-- Verify new counts
SELECT 'AFTER SCALE-UP' as status;
SELECT 'users' as table_name, COUNT(*) as row_count FROM users
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;

-- Summary
SELECT '✅ Data scaled up successfully!' as message;
SELECT '  - 90,000 users (9x increase)' as details
UNION ALL SELECT '  - 95,000 orders (1.9x increase)'
UNION ALL SELECT '  - 9,000 products (9x increase)'
UNION ALL SELECT '  - 99,000 order items (near max capacity!)'
UNION ALL SELECT ''
UNION ALL SELECT '📊 These volumes should give realistic costs!'
UNION ALL SELECT '🚀 Now run: dbt-cost-guard --project-dir example_project estimate';

