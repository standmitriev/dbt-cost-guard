-- Check table statistics in DEMO_DB
SELECT 
    table_schema,
    table_name,
    row_count,
    bytes
FROM DEMO_DB.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'RAW'
ORDER BY table_name;
