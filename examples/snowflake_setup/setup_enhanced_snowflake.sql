-- ============================================================================
-- Enhanced Snowflake Setup for dbt-cost-guard Testing
-- ============================================================================
-- This creates a comprehensive test environment with:
-- - Multiple databases (SALES_DB, ANALYTICS_DB, REFERENCE_DB)
-- - Various schemas and data patterns
-- - Cross-database references
-- - Large datasets for realistic cost testing
-- ============================================================================

-- Cleanup existing (optional - comment out if you want to keep DEMO_DB)
-- DROP DATABASE IF EXISTS DEMO_DB CASCADE;

-- ============================================================================
-- 1. CREATE DATABASES
-- ============================================================================

CREATE DATABASE IF NOT EXISTS SALES_DB;
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB;
CREATE DATABASE IF NOT EXISTS REFERENCE_DB;

-- ============================================================================
-- 2. CREATE SCHEMAS
-- ============================================================================

-- Sales DB schemas
CREATE SCHEMA IF NOT EXISTS SALES_DB.RAW;
CREATE SCHEMA IF NOT EXISTS SALES_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS SALES_DB.MARTS;

-- Analytics DB schemas
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.RAW;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.MARTS;

-- Reference DB schemas
CREATE SCHEMA IF NOT EXISTS REFERENCE_DB.RAW;
CREATE SCHEMA IF NOT EXISTS REFERENCE_DB.STAGING;

-- dbt target schema
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.DBT_COST_GUARD_TEST;

-- ============================================================================
-- 3. SALES_DB - Transactional Data
-- ============================================================================

USE DATABASE SALES_DB;
USE SCHEMA RAW;

-- Customers table (large)
CREATE OR REPLACE TABLE customers (
    customer_id NUMBER(10, 0) PRIMARY KEY,
    email VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    country VARCHAR(50),
    state VARCHAR(50),
    city VARCHAR(100),
    signup_date DATE,
    customer_segment VARCHAR(50),
    lifetime_value DECIMAL(12, 2),
    is_active BOOLEAN,
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ
);

-- Orders table (very large)
CREATE OR REPLACE TABLE orders (
    order_id NUMBER(12, 0) PRIMARY KEY,
    customer_id NUMBER(10, 0),
    order_date DATE,
    order_status VARCHAR(50),
    total_amount DECIMAL(12, 2),
    discount_amount DECIMAL(12, 2),
    tax_amount DECIMAL(12, 2),
    shipping_cost DECIMAL(8, 2),
    payment_method VARCHAR(50),
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ
);

-- Order items table (massive - many-to-one with orders)
CREATE OR REPLACE TABLE order_items (
    order_item_id NUMBER(15, 0) PRIMARY KEY,
    order_id NUMBER(12, 0),
    product_id NUMBER(10, 0),
    quantity NUMBER(6, 0),
    unit_price DECIMAL(10, 2),
    discount_percent DECIMAL(5, 2),
    line_total DECIMAL(12, 2),
    created_at TIMESTAMP_NTZ
);

-- Products table
CREATE OR REPLACE TABLE products (
    product_id NUMBER(10, 0) PRIMARY KEY,
    product_name VARCHAR(255),
    category VARCHAR(100),
    subcategory VARCHAR(100),
    brand VARCHAR(100),
    price DECIMAL(10, 2),
    cost DECIMAL(10, 2),
    weight_kg DECIMAL(8, 2),
    is_active BOOLEAN,
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ
);

-- ============================================================================
-- 4. ANALYTICS_DB - Event and Behavioral Data
-- ============================================================================

USE DATABASE ANALYTICS_DB;
USE SCHEMA RAW;

-- Web events table (huge - clickstream data)
CREATE OR REPLACE TABLE web_events (
    event_id NUMBER(18, 0) PRIMARY KEY,
    customer_id NUMBER(10, 0),
    session_id VARCHAR(100),
    event_timestamp TIMESTAMP_NTZ,
    event_type VARCHAR(50),
    page_url VARCHAR(500),
    referrer_url VARCHAR(500),
    device_type VARCHAR(50),
    browser VARCHAR(50),
    country VARCHAR(50),
    created_at TIMESTAMP_NTZ
);

-- Marketing campaigns table
CREATE OR REPLACE TABLE marketing_campaigns (
    campaign_id NUMBER(8, 0) PRIMARY KEY,
    campaign_name VARCHAR(255),
    channel VARCHAR(50),
    start_date DATE,
    end_date DATE,
    budget DECIMAL(12, 2),
    spend DECIMAL(12, 2),
    impressions NUMBER(12, 0),
    clicks NUMBER(10, 0),
    conversions NUMBER(8, 0),
    created_at TIMESTAMP_NTZ
);

-- Campaign attributions (links orders to campaigns)
CREATE OR REPLACE TABLE campaign_attributions (
    attribution_id NUMBER(15, 0) PRIMARY KEY,
    order_id NUMBER(12, 0),
    campaign_id NUMBER(8, 0),
    attribution_model VARCHAR(50),
    attribution_percent DECIMAL(5, 2),
    created_at TIMESTAMP_NTZ
);

-- ============================================================================
-- 5. REFERENCE_DB - Lookup and Configuration Data
-- ============================================================================

USE DATABASE REFERENCE_DB;
USE SCHEMA RAW;

-- Geography lookup table
CREATE OR REPLACE TABLE geography (
    geo_id NUMBER(6, 0) PRIMARY KEY,
    country VARCHAR(50),
    state VARCHAR(50),
    city VARCHAR(100),
    region VARCHAR(50),
    timezone VARCHAR(50),
    population NUMBER(12, 0),
    median_income DECIMAL(12, 2)
);

-- Product categories hierarchy
CREATE OR REPLACE TABLE product_categories (
    category_id NUMBER(6, 0) PRIMARY KEY,
    category_name VARCHAR(100),
    parent_category_id NUMBER(6, 0),
    level NUMBER(2, 0),
    is_leaf BOOLEAN
);

-- Date dimension
CREATE OR REPLACE TABLE date_dimension (
    date_key NUMBER(8, 0) PRIMARY KEY,
    full_date DATE,
    year NUMBER(4, 0),
    quarter NUMBER(1, 0),
    month NUMBER(2, 0),
    month_name VARCHAR(20),
    week NUMBER(2, 0),
    day_of_month NUMBER(2, 0),
    day_of_week NUMBER(1, 0),
    day_name VARCHAR(20),
    is_weekend BOOLEAN,
    is_holiday BOOLEAN,
    fiscal_year NUMBER(4, 0),
    fiscal_quarter NUMBER(1, 0)
);

-- ============================================================================
-- 6. POPULATE DATA
-- ============================================================================

-- SALES_DB Data Population
USE DATABASE SALES_DB;
USE SCHEMA RAW;

-- Customers (50,000 records)
TRUNCATE TABLE customers;
INSERT INTO customers
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as customer_id,
    'customer_' || customer_id || '@example.com' as email,
    'First' || (customer_id % 1000) as first_name,
    'Last' || (customer_id % 1000) as last_name,
    CASE (customer_id % 5)
        WHEN 0 THEN 'USA'
        WHEN 1 THEN 'Canada'
        WHEN 2 THEN 'UK'
        WHEN 3 THEN 'Germany'
        ELSE 'France'
    END as country,
    'State' || (customer_id % 50) as state,
    'City' || (customer_id % 200) as city,
    DATEADD(day, -UNIFORM(1, 1000, RANDOM()), CURRENT_DATE()) as signup_date,
    CASE (customer_id % 4)
        WHEN 0 THEN 'Premium'
        WHEN 1 THEN 'Standard'
        WHEN 2 THEN 'Basic'
        ELSE 'Trial'
    END as customer_segment,
    UNIFORM(100, 50000, RANDOM()) as lifetime_value,
    (customer_id % 10) != 0 as is_active,
    CURRENT_TIMESTAMP() as created_at,
    CURRENT_TIMESTAMP() as updated_at
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

-- Orders (150,000 records - 3 orders per customer on average)
TRUNCATE TABLE orders;
INSERT INTO orders
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as order_id,
    UNIFORM(1, 50000, RANDOM()) as customer_id,
    DATEADD(day, -UNIFORM(1, 730, RANDOM()), CURRENT_DATE()) as order_date,
    CASE (order_id % 10)
        WHEN 0 THEN 'cancelled'
        WHEN 1 THEN 'returned'
        WHEN 2 THEN 'pending'
        ELSE 'completed'
    END as order_status,
    UNIFORM(20, 2000, RANDOM()) as total_amount,
    UNIFORM(0, 200, RANDOM()) as discount_amount,
    UNIFORM(5, 150, RANDOM()) as tax_amount,
    UNIFORM(5, 50, RANDOM()) as shipping_cost,
    CASE (order_id % 4)
        WHEN 0 THEN 'credit_card'
        WHEN 1 THEN 'paypal'
        WHEN 2 THEN 'bank_transfer'
        ELSE 'cash'
    END as payment_method,
    CURRENT_TIMESTAMP() as created_at,
    CURRENT_TIMESTAMP() as updated_at
FROM TABLE(GENERATOR(ROWCOUNT => 150000));

-- Products (10,000 records)
TRUNCATE TABLE products;
INSERT INTO products
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as product_id,
    'Product ' || product_id as product_name,
    CASE (product_id % 10)
        WHEN 0 THEN 'Electronics'
        WHEN 1 THEN 'Clothing'
        WHEN 2 THEN 'Home & Garden'
        WHEN 3 THEN 'Sports'
        WHEN 4 THEN 'Books'
        WHEN 5 THEN 'Toys'
        WHEN 6 THEN 'Food'
        WHEN 7 THEN 'Beauty'
        WHEN 8 THEN 'Automotive'
        ELSE 'Other'
    END as category,
    'Subcategory ' || (product_id % 50) as subcategory,
    'Brand ' || (product_id % 100) as brand,
    UNIFORM(10, 500, RANDOM()) as price,
    UNIFORM(5, 250, RANDOM()) as cost,
    UNIFORM(0.1, 50.0, RANDOM()) as weight_kg,
    (product_id % 20) != 0 as is_active,
    CURRENT_TIMESTAMP() as created_at,
    CURRENT_TIMESTAMP() as updated_at
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

-- Order items (500,000 records - multiple items per order)
TRUNCATE TABLE order_items;
INSERT INTO order_items
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as order_item_id,
    UNIFORM(1, 150000, RANDOM()) as order_id,
    UNIFORM(1, 10000, RANDOM()) as product_id,
    UNIFORM(1, 10, RANDOM()) as quantity,
    UNIFORM(10, 500, RANDOM()) as unit_price,
    UNIFORM(0, 20, RANDOM()) as discount_percent,
    UNIFORM(10, 1000, RANDOM()) as line_total,
    CURRENT_TIMESTAMP() as created_at
FROM TABLE(GENERATOR(ROWCOUNT => 500000));

-- ANALYTICS_DB Data Population
USE DATABASE ANALYTICS_DB;
USE SCHEMA RAW;

-- Web events (1,000,000 records - large dataset for expensive queries)
TRUNCATE TABLE web_events;
INSERT INTO web_events
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as event_id,
    UNIFORM(1, 50000, RANDOM()) as customer_id,
    'session_' || UNIFORM(1, 200000, RANDOM()) as session_id,
    DATEADD(second, -UNIFORM(1, 7776000, RANDOM()), CURRENT_TIMESTAMP()) as event_timestamp,
    CASE (event_id % 8)
        WHEN 0 THEN 'page_view'
        WHEN 1 THEN 'product_view'
        WHEN 2 THEN 'add_to_cart'
        WHEN 3 THEN 'remove_from_cart'
        WHEN 4 THEN 'checkout_start'
        WHEN 5 THEN 'purchase'
        WHEN 6 THEN 'search'
        ELSE 'bounce'
    END as event_type,
    '/page/' || UNIFORM(1, 1000, RANDOM()) as page_url,
    CASE WHEN UNIFORM(0, 2, RANDOM()) = 0 THEN NULL ELSE '/ref/' || UNIFORM(1, 500, RANDOM()) END as referrer_url,
    CASE (event_id % 4)
        WHEN 0 THEN 'desktop'
        WHEN 1 THEN 'mobile'
        WHEN 2 THEN 'tablet'
        ELSE 'other'
    END as device_type,
    CASE (event_id % 5)
        WHEN 0 THEN 'Chrome'
        WHEN 1 THEN 'Firefox'
        WHEN 2 THEN 'Safari'
        WHEN 3 THEN 'Edge'
        ELSE 'Other'
    END as browser,
    CASE (event_id % 5)
        WHEN 0 THEN 'USA'
        WHEN 1 THEN 'Canada'
        WHEN 2 THEN 'UK'
        WHEN 3 THEN 'Germany'
        ELSE 'France'
    END as country,
    CURRENT_TIMESTAMP() as created_at
FROM TABLE(GENERATOR(ROWCOUNT => 1000000));

-- Marketing campaigns (200 records)
TRUNCATE TABLE marketing_campaigns;
INSERT INTO marketing_campaigns
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as campaign_id,
    'Campaign ' || campaign_id as campaign_name,
    CASE (campaign_id % 5)
        WHEN 0 THEN 'email'
        WHEN 1 THEN 'social'
        WHEN 2 THEN 'search'
        WHEN 3 THEN 'display'
        ELSE 'affiliate'
    END as channel,
    DATEADD(day, -UNIFORM(180, 730, RANDOM()), CURRENT_DATE()) as start_date,
    DATEADD(day, UNIFORM(30, 90, RANDOM()), start_date) as end_date,
    UNIFORM(10000, 500000, RANDOM()) as budget,
    UNIFORM(5000, 450000, RANDOM()) as spend,
    UNIFORM(100000, 5000000, RANDOM()) as impressions,
    UNIFORM(1000, 100000, RANDOM()) as clicks,
    UNIFORM(100, 5000, RANDOM()) as conversions,
    CURRENT_TIMESTAMP() as created_at
FROM TABLE(GENERATOR(ROWCOUNT => 200));

-- Campaign attributions (100,000 records)
TRUNCATE TABLE campaign_attributions;
INSERT INTO campaign_attributions
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as attribution_id,
    UNIFORM(1, 150000, RANDOM()) as order_id,
    UNIFORM(1, 200, RANDOM()) as campaign_id,
    CASE (attribution_id % 3)
        WHEN 0 THEN 'first_touch'
        WHEN 1 THEN 'last_touch'
        ELSE 'linear'
    END as attribution_model,
    UNIFORM(10, 100, RANDOM()) as attribution_percent,
    CURRENT_TIMESTAMP() as created_at
FROM TABLE(GENERATOR(ROWCOUNT => 100000));

-- REFERENCE_DB Data Population
USE DATABASE REFERENCE_DB;
USE SCHEMA RAW;

-- Geography (1000 records)
TRUNCATE TABLE geography;
INSERT INTO geography
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as geo_id,
    CASE (geo_id % 5)
        WHEN 0 THEN 'USA'
        WHEN 1 THEN 'Canada'
        WHEN 2 THEN 'UK'
        WHEN 3 THEN 'Germany'
        ELSE 'France'
    END as country,
    'State' || (geo_id % 50) as state,
    'City' || geo_id as city,
    'Region' || (geo_id % 10) as region,
    'UTC' || (geo_id % 24 - 12) as timezone,
    UNIFORM(10000, 5000000, RANDOM()) as population,
    UNIFORM(30000, 150000, RANDOM()) as median_income
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- Product categories (100 records)
TRUNCATE TABLE product_categories;
INSERT INTO product_categories
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) as category_id,
    'Category ' || category_id as category_name,
    CASE WHEN category_id > 10 THEN UNIFORM(1, 10, RANDOM()) ELSE NULL END as parent_category_id,
    CASE WHEN category_id <= 10 THEN 1 ELSE 2 END as level,
    category_id > 10 as is_leaf
FROM TABLE(GENERATOR(ROWCOUNT => 100));

-- Date dimension (3 years of dates)
TRUNCATE TABLE date_dimension;
INSERT INTO date_dimension
SELECT
    TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD')) as date_key,
    full_date,
    YEAR(full_date) as year,
    QUARTER(full_date) as quarter,
    MONTH(full_date) as month,
    MONTHNAME(full_date) as month_name,
    WEEKOFYEAR(full_date) as week,
    DAY(full_date) as day_of_month,
    DAYOFWEEK(full_date) as day_of_week,
    DAYNAME(full_date) as day_name,
    DAYOFWEEK(full_date) IN (0, 6) as is_weekend,
    FALSE as is_holiday,
    YEAR(full_date) as fiscal_year,
    QUARTER(full_date) as fiscal_quarter
FROM (
    SELECT DATEADD(day, SEQ4(), '2022-01-01'::DATE) as full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 1095))
)
WHERE full_date < '2025-01-01';

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================

-- Grant usage on all databases
GRANT USAGE ON DATABASE SALES_DB TO ROLE SYSADMIN;
GRANT USAGE ON DATABASE ANALYTICS_DB TO ROLE SYSADMIN;
GRANT USAGE ON DATABASE REFERENCE_DB TO ROLE SYSADMIN;

-- Grant usage on all schemas
GRANT USAGE ON ALL SCHEMAS IN DATABASE SALES_DB TO ROLE SYSADMIN;
GRANT USAGE ON ALL SCHEMAS IN DATABASE ANALYTICS_DB TO ROLE SYSADMIN;
GRANT USAGE ON ALL SCHEMAS IN DATABASE REFERENCE_DB TO ROLE SYSADMIN;

-- Grant select on all tables
GRANT SELECT ON ALL TABLES IN DATABASE SALES_DB TO ROLE SYSADMIN;
GRANT SELECT ON ALL TABLES IN DATABASE ANALYTICS_DB TO ROLE SYSADMIN;
GRANT SELECT ON ALL TABLES IN DATABASE REFERENCE_DB TO ROLE SYSADMIN;

-- Grant create table permissions for dbt
GRANT CREATE TABLE ON SCHEMA ANALYTICS_DB.DBT_COST_GUARD_TEST TO ROLE SYSADMIN;
GRANT CREATE VIEW ON SCHEMA ANALYTICS_DB.DBT_COST_GUARD_TEST TO ROLE SYSADMIN;

-- ============================================================================
-- 8. VERIFY DATA
-- ============================================================================

SELECT 'SALES_DB.RAW.customers' as table_name, COUNT(*) as row_count FROM SALES_DB.RAW.customers
UNION ALL
SELECT 'SALES_DB.RAW.orders', COUNT(*) FROM SALES_DB.RAW.orders
UNION ALL
SELECT 'SALES_DB.RAW.order_items', COUNT(*) FROM SALES_DB.RAW.order_items
UNION ALL
SELECT 'SALES_DB.RAW.products', COUNT(*) FROM SALES_DB.RAW.products
UNION ALL
SELECT 'ANALYTICS_DB.RAW.web_events', COUNT(*) FROM ANALYTICS_DB.RAW.web_events
UNION ALL
SELECT 'ANALYTICS_DB.RAW.marketing_campaigns', COUNT(*) FROM ANALYTICS_DB.RAW.marketing_campaigns
UNION ALL
SELECT 'ANALYTICS_DB.RAW.campaign_attributions', COUNT(*) FROM ANALYTICS_DB.RAW.campaign_attributions
UNION ALL
SELECT 'REFERENCE_DB.RAW.geography', COUNT(*) FROM REFERENCE_DB.RAW.geography
UNION ALL
SELECT 'REFERENCE_DB.RAW.product_categories', COUNT(*) FROM REFERENCE_DB.RAW.product_categories
UNION ALL
SELECT 'REFERENCE_DB.RAW.date_dimension', COUNT(*) FROM REFERENCE_DB.RAW.date_dimension
ORDER BY table_name;

-- ============================================================================
-- Setup complete!
-- 
-- Data Summary:
-- - SALES_DB: 50K customers, 150K orders, 500K order items, 10K products
-- - ANALYTICS_DB: 1M web events, 200 campaigns, 100K attributions
-- - REFERENCE_DB: 1K geography, 100 categories, 1095 dates
-- 
-- Total rows: ~1.76 million records across 10 tables
-- ============================================================================

