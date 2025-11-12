# Manual Testing Guide for Schema Migration (Indexes, Triggers, Constraints)

This guide explains how to manually test the Postgres-to-Postgres schema migration feature that automatically migrates indexes, triggers, and constraints.

## Prerequisites

1. PeerDB running in Docker (see `SETUP.md`)
2. Demo databases running (see `demo-databases/README.md`)
3. Access to PeerDB UI at `http://localhost:3000`

## Test Database Setup

The `ecommerce` database (demo-source-1, port 5433) contains tables with indexes, triggers, and constraints that we'll use for testing.

### Verify Source Database Schema

Connect to the source database and verify it has schema objects:

```bash
# Connect to source database
psql -h localhost -p 5433 -U postgres -d ecommerce

# Run the verification script
\i demo-databases/verify-schema.sql
```

You should see:
- **Indexes**: Multiple indexes on tables (e.g., `idx_orders_user_id`, `idx_products_name`)
- **Triggers**: Triggers on tables (if any exist)
- **Constraints**: Foreign keys, unique constraints, check constraints

## Manual Testing Steps

### Step 1: Create Peers

1. Open PeerDB UI: `http://localhost:3000`
2. Create Source Peer:
   - Go to "Peers" → "Create Peer"
   - Type: PostgreSQL
   - Name: `ecommerce-source`
   - Host: `demo-source-1` (or `host.docker.internal` if PeerDB is not on same network)
   - Port: `5432` (internal port) or `5433` (if using host.docker.internal)
   - Database: `ecommerce`
   - User: `postgres`
   - Password: `postgres`

3. Create Destination Peer:
   - Go to "Peers" → "Create Peer"
   - Type: PostgreSQL
   - Name: `ecommerce-dest`
   - Host: `demo-dest` (or `host.docker.internal`)
   - Port: `5432` (internal port) or `5435` (if using host.docker.internal)
   - Database: `postgres` (or create a new database)
   - User: `postgres`
   - Password: `postgres`

### Step 2: Create a Mirror (CDC Flow)

1. Go to "Mirrors" → "Create Mirror"
2. Select "CDC" as the mirror type
3. Configure the mirror:
   - **Source Peer**: `ecommerce-source`
   - **Destination Peer**: `ecommerce-dest`
   - **Tables**: Select one or more tables (e.g., `public.orders`, `public.products`)
   - **Mirror Name**: `test-schema-migration`

4. Click "Create Mirror"

### Step 3: Verify Schema Migration

After the mirror is created, the schema migration should happen automatically during the initial table setup. 

**Important**: Schema migration happens automatically when tables are first created. You should see log messages in PeerDB indicating schema objects are being migrated.

To verify that indexes, triggers, and constraints were successfully migrated:

#### Option A: Quick Verification (Count Comparison)

First, compare the counts between source and destination:

```bash
# Source database - get counts
psql -h localhost -p 5433 -U postgres -d ecommerce -c "
SELECT 'INDEXES' as type, COUNT(*) as count FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('users', 'products', 'orders', 'order_items')
UNION ALL
SELECT 'TRIGGERS', COUNT(*) FROM pg_trigger t 
  JOIN pg_class c ON t.tgrelid = c.oid 
  JOIN pg_namespace n ON c.relnamespace = n.oid 
  WHERE n.nspname = 'public' AND c.relname IN ('users', 'products', 'orders', 'order_items') AND NOT t.tgisinternal
UNION ALL
SELECT 'CONSTRAINTS', COUNT(*) FROM pg_constraint con 
  JOIN pg_class t ON con.conrelid = t.oid 
  JOIN pg_namespace n ON t.relnamespace = n.oid 
  WHERE n.nspname = 'public' AND t.relname IN ('users', 'products', 'orders', 'order_items') AND t.relname NOT LIKE 'pg_%';
"

# Destination database - get counts (replace 'postgres' with your destination database name)
psql -h localhost -p 5435 -U postgres -d postgres -c "
SELECT 'INDEXES' as type, COUNT(*) as count FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('users', 'products', 'orders', 'order_items')
UNION ALL
SELECT 'TRIGGERS', COUNT(*) FROM pg_trigger t 
  JOIN pg_class c ON t.tgrelid = c.oid 
  JOIN pg_namespace n ON c.relnamespace = n.oid 
  WHERE n.nspname = 'public' AND c.relname IN ('users', 'products', 'orders', 'order_items') AND NOT t.tgisinternal
UNION ALL
SELECT 'CONSTRAINTS', COUNT(*) FROM pg_constraint con 
  JOIN pg_class t ON con.conrelid = t.oid 
  JOIN pg_namespace n ON t.relnamespace = n.oid 
  WHERE n.nspname = 'public' AND t.relname IN ('users', 'products', 'orders', 'order_items') AND t.relname NOT LIKE 'pg_%';
"
```

**Expected Result**: The counts should match (or be very close - destination might have a few extra PeerDB internal constraints).

#### Option B: Detailed Verification (See All Objects)

```bash
# Connect to destination database
psql -h localhost -p 5435 -U postgres -d postgres

# Check indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('users', 'products', 'orders', 'order_items')
ORDER BY tablename, indexname;

# Check triggers
SELECT 
    n.nspname AS schema_name,
    t.tgname AS trigger_name,
    c.relname AS table_name,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND c.relname IN ('users', 'products', 'orders', 'order_items')
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;

# Check constraints
SELECT
    n.nspname AS schema_name,
    t.relname AS table_name,
    con.conname AS constraint_name,
    CASE con.contype
        WHEN 'p' THEN 'PRIMARY KEY'
        WHEN 'f' THEN 'FOREIGN KEY'
        WHEN 'u' THEN 'UNIQUE'
        WHEN 'c' THEN 'CHECK'
        ELSE con.contype::text
    END AS constraint_type,
    pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_class t ON con.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND t.relname IN ('users', 'products', 'orders', 'order_items')
  AND t.relname NOT LIKE 'pg_%'
ORDER BY t.relname, con.conname;
```

#### Option C: Check PeerDB Logs for Migration Messages

Look for log messages indicating schema migration:

```bash
# Check for schema migration log messages
docker logs peerdb-flow-1 2>&1 | grep -i "schema\|migration\|index\|trigger\|constraint" | tail -20
```

You should see messages like:
- `[schema migration] creating index ...`
- `[schema migration] creating trigger ...`
- `[schema migration] creating constraint ...`
- `Successfully migrated schema objects for X tables`

### Step 4: Compare Source and Destination

Compare the schema objects between source and destination:

```bash
# Source database
psql -h localhost -p 5433 -U postgres -d ecommerce -c "
SELECT 'INDEXES' as type, COUNT(*) as count FROM pg_indexes WHERE schemaname = 'public'
UNION ALL
SELECT 'TRIGGERS', COUNT(*) FROM pg_trigger t 
  JOIN pg_class c ON t.tgrelid = c.oid 
  JOIN pg_namespace n ON c.relnamespace = n.oid 
  WHERE n.nspname = 'public' AND NOT t.tgisinternal
UNION ALL
SELECT 'CONSTRAINTS', COUNT(*) FROM pg_constraint con 
  JOIN pg_class t ON con.conrelid = t.oid 
  JOIN pg_namespace n ON t.relnamespace = n.oid 
  WHERE n.nspname = 'public' AND t.relname NOT LIKE 'pg_%';
"

# Destination database
psql -h localhost -p 5435 -U postgres -d postgres -c "
SELECT 'INDEXES' as type, COUNT(*) as count FROM pg_indexes WHERE schemaname = 'public'
UNION ALL
SELECT 'TRIGGERS', COUNT(*) FROM pg_trigger t 
  JOIN pg_class c ON t.tgrelid = c.oid 
  JOIN pg_namespace n ON c.relnamespace = n.oid 
  WHERE n.nspname = 'public' AND NOT t.tgisinternal
UNION ALL
SELECT 'CONSTRAINTS', COUNT(*) FROM pg_constraint con 
  JOIN pg_class t ON con.conrelid = t.oid 
  JOIN pg_namespace n ON t.relnamespace = n.oid 
  WHERE n.nspname = 'public' AND t.relname NOT LIKE 'pg_%';
"
```

## Expected Results

After creating a mirror:

1. **Tables**: Destination tables should be created with the same structure as source
2. **Indexes**: All non-primary indexes from source should be created on destination
   - For ecommerce database: You should see indexes like `idx_orders_user_id`, `idx_orders_created_at`, `idx_order_items_order_id`, `idx_order_items_product_id`, `idx_products_category`
3. **Triggers**: All triggers from source should be created on destination (including trigger functions)
   - Note: The ecommerce database doesn't have triggers, so you won't see any
4. **Constraints**: All constraints (foreign keys, unique, check) from source should be created on destination
   - For ecommerce database: You should see foreign keys on `orders.user_id`, `order_items.order_id`, `order_items.product_id`, and unique constraint on `users.email`

## Quick Verification Steps

After creating a mirror, follow these steps to confirm schema migration worked:

### Step 1: Check PeerDB Logs

Look for schema migration messages in the logs:

```bash
docker logs flow-worker 2>&1 | grep -i "schema\|migration\|index\|trigger\|constraint" | tail -30
```

**What to look for:**
- `[schema migration] creating index ...` - Shows indexes being created
- `[schema migration] creating constraint ...` - Shows constraints being created
- `[schema migration] creating trigger ...` - Shows triggers being created
- `Successfully migrated schema objects for X tables` - Confirms migration completed

**If you see warnings**: That's okay - some constraints might fail, but indexes should still be created.

### Step 2: Compare Index Counts

Compare the number of indexes between source and destination:

```bash
# Source database (should show ~10 indexes for the 4 tables)
psql -h localhost -p 5433 -U postgres -d ecommerce -c "
SELECT COUNT(*) FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN ('users', 'products', 'orders', 'order_items');"

# Destination database (should match or be close)
psql -h localhost -p 5435 -U postgres -d warehouse -c "
SELECT COUNT(*) FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN ('users', 'products', 'orders', 'order_items');"
```

**Expected**: Destination should have similar count (may be slightly different due to unique constraint indexes).

### Step 3: Verify Specific Indexes Exist

Check that specific indexes were migrated. You can check all four tables or just a subset:

**Option A: Check all four tables (recommended for full verification)**

```bash
psql -h localhost -p 5435 -U postgres -d warehouse -c "
SELECT tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN ('users', 'products', 'orders', 'order_items')
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;"
```

**Option B: Quick check - just orders and products**

```bash
# Source database
psql -h localhost -p 5433 -U postgres -d ecommerce -c "
SELECT tablename, indexname 
FROM pg_indexes 
WHERE tablename IN ('orders', 'products')
  AND indexname LIKE 'idx_%';"

# Destination database
psql -h localhost -p 5435 -U postgres -d warehouse -c "
SELECT tablename, indexname 
FROM pg_indexes 
WHERE tablename IN ('orders', 'products')
  AND indexname LIKE 'idx_%';"
```

**Expected indexes:**
- `idx_orders_user_id`
- `idx_orders_created_at`
- `idx_order_items_order_id`
- `idx_order_items_product_id`
- `idx_products_category`

### Step 4: Verify Constraints

Check that foreign keys and unique constraints were migrated:

```bash
psql -h localhost -p 5435 -U postgres -d postgres -c "
SELECT 
    t.relname AS table_name,
    con.conname AS constraint_name,
    CASE con.contype
        WHEN 'f' THEN 'FOREIGN KEY'
        WHEN 'u' THEN 'UNIQUE'
        ELSE con.contype::text
    END AS constraint_type
FROM pg_constraint con
JOIN pg_class t ON con.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND t.relname IN ('users', 'products', 'orders', 'order_items')
  AND con.contype IN ('f', 'u')
ORDER BY t.relname, con.conname;"
```

**Expected constraints:**
- Foreign keys: `orders_user_id_fkey`, `order_items_order_id_fkey`, `order_items_product_id_fkey`
- Unique: `users_email_key`

## Quick Verification Queries

Here are the exact queries to quickly verify schema migration worked:

### 1. Compare Index Counts (Source vs Destination)

```bash
# Source database
psql -h localhost -p 5433 -U postgres -d ecommerce -c "
SELECT COUNT(*) FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN ('users', 'products', 'orders', 'order_items');"

# Destination database
psql -h localhost -p 5435 -U postgres -d warehouse -c "
SELECT COUNT(*) FROM pg_indexes 
WHERE schemaname = 'public' 
  AND tablename IN ('users', 'products', 'orders', 'order_items');"
```

### 2. Check Specific Indexes (Quick Check - Orders & Products)

```bash
# Source database
psql -h localhost -p 5433 -U postgres -d ecommerce -c "
SELECT tablename, indexname 
FROM pg_indexes 
WHERE tablename IN ('orders', 'products')
  AND indexname LIKE 'idx_%';"

# Destination database
psql -h localhost -p 5435 -U postgres -d warehouse -c "
SELECT tablename, indexname 
FROM pg_indexes 
WHERE tablename IN ('orders', 'products')
  AND indexname LIKE 'idx_%';"
```

**Note**: Checking `orders` and `products` is usually sufficient since they have the most indexes. If you want to verify all four tables, use the queries in Step 3 above.

## Verification Checklist

Use this checklist to confirm schema migration worked:

- [ ] PeerDB logs show `[schema migration] creating index` messages
- [ ] PeerDB logs show `Successfully migrated schema objects` (or at least index creation messages)
- [ ] PeerDB logs show `verified indexes after commit` with matching counts
- [ ] Index count in destination matches source (or is close)
- [ ] Specific indexes exist: `idx_orders_user_id`, `idx_products_category`, etc.
- [ ] Foreign key constraints exist (check `orders` and `order_items` tables)
- [ ] Unique constraints exist (check `users.email`)

## Troubleshooting

### Temporal Search Attribute Error

**Error**: `Namespace default has no mapping defined for search attribute MirrorName`

**What it is**: Temporal uses search attributes to index and query workflows. The `MirrorName` attribute allows PeerDB to search for workflows by mirror name.

**Why it was missing**: The initialization script (`mirror-name-search.sh`) should create this automatically, but it may not run if:
- The Temporal admin tools container starts before Temporal is fully ready
- The script hasn't executed yet
- Containers were restarted and the script didn't run

**Fix**: Manually create the search attribute:
```bash
docker exec temporal-admin-tools temporal operator search-attribute create --name MirrorName --type Text --namespace default
```

**Verify it exists**:
```bash
docker exec temporal-admin-tools temporal operator search-attribute list --namespace default | grep MirrorName
```

### Schema objects not migrated

1. Check PeerDB logs for errors:
   ```bash
   docker logs peerdb-flow-1 | grep -i "schema\|migration\|index\|trigger\|constraint"
   ```

2. Verify both peers are PostgreSQL:
   - The migration only works for Postgres-to-Postgres mirrors
   - Check peer types in the UI

3. Check if tables were created:
   - If tables weren't created, schema migration won't run
   - Schema migration happens after table creation

### Indexes not visible immediately

- Indexes are created in a transaction and should be visible after commit
- If you don't see them, wait a few seconds and query again
- Check if indexes were actually created by querying `pg_index` directly

### Constraints fail to create

- Foreign key constraints require referenced tables to exist first
- Unique constraints create underlying indexes that might conflict
- Check PeerDB logs for specific error messages

## Testing with Custom Tables

To test with your own tables:

1. Create a table in the source database with indexes, triggers, and constraints
2. Create a mirror selecting that table
3. Verify the schema objects were migrated

Example:

```sql
-- In source database
CREATE TABLE test_migration (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_name ON test_migration(name);
CREATE UNIQUE INDEX idx_email ON test_migration(email);
CREATE INDEX idx_created_at ON test_migration(created_at DESC);

CREATE FUNCTION update_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_timestamp
    BEFORE UPDATE ON test_migration
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

ALTER TABLE test_migration ADD CONSTRAINT chk_name_length CHECK (LENGTH(name) > 0);
ALTER TABLE test_migration ADD CONSTRAINT uq_email_constraint UNIQUE (email);
```

Then create a mirror for this table and verify all schema objects were migrated.

