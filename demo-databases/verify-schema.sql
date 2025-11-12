-- Script to verify indexes, triggers, and constraints in demo databases
-- Run this against each database to see what schema elements exist

\echo '=== INDEXES ==='
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

\echo ''
\echo '=== TRIGGERS ==='
SELECT 
    n.nspname AS schema_name,
    t.tgname AS trigger_name,
    c.relname AS table_name,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;

\echo ''
\echo '=== CONSTRAINTS ==='
SELECT
    n.nspname AS schema_name,
    t.relname AS table_name,
    con.conname AS constraint_name,
    CASE con.contype
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'f' THEN 'FOREIGN KEY'
        WHEN 'u' THEN 'UNIQUE'
        WHEN 'c' THEN 'CHECK'
        WHEN 't' THEN 'TRIGGER'
        WHEN 'x' THEN 'EXCLUSION'
    END AS constraint_type,
    pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_class t ON con.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND con.contype IN ('p', 'f', 'u', 'c')
ORDER BY t.relname, con.conname;

\echo ''
\echo '=== SUMMARY ==='
SELECT 
    'Indexes' AS element_type,
    COUNT(*) AS count
FROM pg_indexes
WHERE schemaname = 'public'
UNION ALL
SELECT 
    'Triggers' AS element_type,
    COUNT(*) AS count
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public' AND NOT t.tgisinternal
UNION ALL
SELECT 
    'Constraints' AS element_type,
    COUNT(*) AS count
FROM pg_constraint con
JOIN pg_class t ON con.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND con.contype IN ('p', 'f', 'u', 'c');

