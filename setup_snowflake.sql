-- Setup script for dbt Cost Guard demo
-- Run this in Snowflake to create test data

-- Create database and schema
CREATE DATABASE IF NOT EXISTS DEMO_DB;
USE DATABASE DEMO_DB;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS DBT_COST_GUARD_DEMO;

-- Create warehouse if not exists (or use existing)
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
  WITH WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE;

USE WAREHOUSE COMPUTE_WH;

-- Create raw tables with sample data
USE SCHEMA RAW;

-- Users table (10,000 users)
CREATE OR REPLACE TABLE users AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as id,
    'user' || ROW_NUMBER() OVER (ORDER BY SEQ4()) || '@example.com' as email,
    'First' || ROW_NUMBER() OVER (ORDER BY SEQ4()) as first_name,
    'Last' || ROW_NUMBER() OVER (ORDER BY SEQ4()) as last_name,
    DATEADD(day, -UNIFORM(1, 1000, RANDOM()), CURRENT_DATE()) as created_at,
    CURRENT_TIMESTAMP() as updated_at,
    NULL as deleted_at
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

-- Orders table (50,000 orders)
CREATE OR REPLACE TABLE orders AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as id,
    UNIFORM(1, 10000, RANDOM()) as user_id,
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
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

-- Products table (1,000 products)
CREATE OR REPLACE TABLE products AS
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
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- Order items table (100,000 items)
CREATE OR REPLACE TABLE order_items AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as id,
    UNIFORM(1, 50000, RANDOM()) as order_id,
    UNIFORM(1, 1000, RANDOM()) as product_id,
    UNIFORM(1, 5, RANDOM()) as quantity,
    UNIFORM(10, 500, RANDOM()) as unit_price
FROM TABLE(GENERATOR(ROWCOUNT => 100000));

-- Grant permissions
GRANT USAGE ON DATABASE DEMO_DB TO ROLE ACCOUNTADMIN;
GRANT USAGE ON SCHEMA DEMO_DB.RAW TO ROLE ACCOUNTADMIN;
GRANT USAGE ON SCHEMA DEMO_DB.DBT_COST_GUARD_DEMO TO ROLE ACCOUNTADMIN;
GRANT SELECT ON ALL TABLES IN SCHEMA DEMO_DB.RAW TO ROLE ACCOUNTADMIN;
GRANT ALL ON SCHEMA DEMO_DB.DBT_COST_GUARD_DEMO TO ROLE ACCOUNTADMIN;

-- Verify data
SELECT 'users' as table_name, COUNT(*) as row_count FROM users
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;

SELECT '✅ Setup complete! You now have:' as status;
SELECT '  - DEMO_DB database' as info
UNION ALL SELECT '  - RAW schema with 4 tables'
UNION ALL SELECT '  - 10,000 users'
UNION ALL SELECT '  - 50,000 orders'
UNION ALL SELECT '  - 1,000 products'
UNION ALL SELECT '  - 100,000 order items'
UNION ALL SELECT '  - COMPUTE_WH warehouse (MEDIUM)'
UNION ALL SELECT ''
UNION ALL SELECT '🚀 Ready to run dbt-cost-guard!';

