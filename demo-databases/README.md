# Demo Databases for PeerDB

This directory contains setup scripts for demo PostgreSQL databases that you can use to test PeerDB's ETL capabilities.

## What's Included

### Demo Source Databases

1. **demo-source-1 (E-commerce)** - Port 5433
   - Database: `ecommerce`
   - Contains: users, products, orders, order_items tables
   - Simulates a typical e-commerce application

2. **demo-source-2 (Analytics)** - Port 5434
   - Database: `analytics`
   - Contains: events, page_views, user_sessions, daily_metrics tables
   - Simulates an analytics/events tracking system

### Demo Destination Database

3. **demo-dest (Data Warehouse)** - Port 5435
   - Database: `warehouse`
   - Empty database ready to receive synced data

## Quick Start

### 1. Start the Demo Databases

```bash
cd demo-databases
docker compose -f docker-compose-demo-dbs.yml up -d
```

This will start all three demo databases with sample data pre-loaded.

### 2. Verify They're Running

```bash
docker ps | grep demo
```

You should see:
- `demo-source-1` on port 5433
- `demo-source-2` on port 5434
- `demo-dest` on port 5435

### 3. Connect and Explore

**E-commerce Database:**
```bash
psql "port=5433 host=localhost user=postgres password=postgres dbname=ecommerce"
```

**Analytics Database:**
```bash
psql "port=5434 host=localhost user=postgres password=postgres dbname=analytics"
```

**Warehouse Database:**
```bash
psql "port=5435 host=localhost user=postgres password=postgres dbname=warehouse"
```

### 4. Create Peers in PeerDB

Now connect to PeerDB (port 9900) and create peers for these databases.

**⚠️ Important:** Since PeerDB runs in Docker containers, you need to use container names or `host.docker.internal`, not `localhost`.

**Option 1: Using Container Names (Recommended)**

If PeerDB and demo databases are on the same Docker network (`peerdb_network`), use container names with internal port `5432`:

```sql
-- Create peer for e-commerce source
CREATE PEER ecommerce_source FROM POSTGRES WITH (
    host = 'demo-source-1',  -- Container name
    port = '5432',           -- Internal port (not 5433)
    user = 'postgres',
    password = 'postgres',
    database = 'ecommerce'
);

-- Create peer for analytics source
CREATE PEER analytics_source FROM POSTGRES WITH (
    host = 'demo-source-2',  -- Container name
    port = '5432',           -- Internal port (not 5434)
    user = 'postgres',
    password = 'postgres',
    database = 'analytics'
);

-- Create peer for warehouse destination
CREATE PEER warehouse_dest FROM POSTGRES WITH (
    host = 'demo-dest',       -- Container name
    port = '5432',           -- Internal port (not 5435)
    user = 'postgres',
    password = 'postgres',
    database = 'warehouse'
);
```

**Option 2: Using host.docker.internal**

If container names don't work, use `host.docker.internal` with host ports:

```sql
-- Create peer for e-commerce source
CREATE PEER ecommerce_source FROM POSTGRES WITH (
    host = 'host.docker.internal',
    port = '5433',           -- Host port
    user = 'postgres',
    password = 'postgres',
    database = 'ecommerce'
);

-- Create peer for analytics source
CREATE PEER analytics_source FROM POSTGRES WITH (
    host = 'host.docker.internal',
    port = '5434',           -- Host port
    user = 'postgres',
    password = 'postgres',
    database = 'analytics'
);

-- Create peer for warehouse destination
CREATE PEER warehouse_dest FROM POSTGRES WITH (
    host = 'host.docker.internal',
    port = '5435',           -- Host port
    user = 'postgres',
    password = 'postgres',
    database = 'warehouse'
);
```

### 5. Create Your First Mirror

Sync e-commerce data to the warehouse:

```sql
CREATE MIRROR ecommerce_to_warehouse FROM ecommerce_source TO warehouse_dest (
    TABLE public.users,
    TABLE public.products,
    TABLE public.orders,
    TABLE public.order_items
);
```

Or sync analytics data:

```sql
CREATE MIRROR analytics_to_warehouse FROM analytics_source TO warehouse_dest (
    TABLE public.events,
    TABLE public.page_views,
    TABLE public.user_sessions,
    TABLE public.daily_metrics
);
```

### 6. Monitor the Sync

```sql
-- Check mirror status
SELECT * FROM peerdb_mirror_status('ecommerce_to_warehouse');

-- View sync statistics
SELECT * FROM peerdb_mirror_stats('ecommerce_to_warehouse');
```

## Database Schemas

### E-commerce Database (`ecommerce`)

**Tables:**
- `users` - Customer information
- `products` - Product catalog
- `orders` - Customer orders
- `order_items` - Items in each order

**Views:**
- `order_summary` - Summary of orders with customer info

### Analytics Database (`analytics`)

**Tables:**
- `events` - User events with JSONB data
- `page_views` - Page view tracking
- `user_sessions` - Session information
- `daily_metrics` - Aggregated daily metrics

**Materialized Views:**
- `event_summary` - Summary of events by type and date

## Testing Different Scenarios

### Test CDC (Change Data Capture)

1. Create a mirror with CDC enabled (default)
2. Insert/update/delete data in the source database
3. Watch it sync in real-time to the destination

```sql
-- In the ecommerce database
INSERT INTO users (email, first_name, last_name) 
VALUES ('newuser@example.com', 'New', 'User');

-- Check the warehouse to see it synced
```

### Test Initial Snapshot Only

```sql
CREATE MIRROR snapshot_test FROM ecommerce_source TO warehouse_dest (
    TABLE public.products,
    INITIAL_SNAPSHOT_ONLY = true
);
```

### Test Query Replication (QRep)

```sql
CREATE MIRROR qrep_test FROM analytics_source TO warehouse_dest (
    QUERY 'SELECT * FROM public.events WHERE created_at > $1',
    INTERVAL 60  -- Run every 60 seconds
);
```

### Test Schema Changes

1. Create a mirror
2. Add a column to a table in the source
3. Watch PeerDB handle the schema change automatically

```sql
-- In source database
ALTER TABLE users ADD COLUMN phone VARCHAR(20);

-- PeerDB will detect and sync the schema change
```

## Stopping the Demo Databases

```bash
cd demo-databases
docker compose -f docker-compose-demo-dbs.yml down
```

To also remove the data volumes:

```bash
docker compose -f docker-compose-demo-dbs.yml down -v
```

## Connecting from PeerDB Containers (Web UI)

When creating peers in the PeerDB Web UI (http://localhost:3000), use these connection details:

### Using Container Names (Recommended)

**E-commerce Database:**
- Host: `demo-source-1`
- Port: `5432`
- User: `postgres`
- Password: `postgres`
- Database: `ecommerce`

**Analytics Database:**
- Host: `demo-source-2`
- Port: `5432`
- User: `postgres`
- Password: `postgres`
- Database: `analytics`

**Warehouse Database:**
- Host: `demo-dest`
- Port: `5432`
- User: `postgres`
- Password: `postgres`
- Database: `warehouse`

### Using host.docker.internal (Alternative)

If container names don't work, use `host.docker.internal` with host ports:

**E-commerce Database:**
- Host: `host.docker.internal`
- Port: `5433` (host port)
- User: `postgres`
- Password: `postgres`
- Database: `ecommerce`

**Analytics Database:**
- Host: `host.docker.internal`
- Port: `5434` (host port)
- User: `postgres`
- Password: `postgres`
- Database: `analytics`

**Warehouse Database:**
- Host: `host.docker.internal`
- Port: `5435` (host port)
- User: `postgres`
- Password: `postgres`
- Database: `warehouse`

## Adding More Sample Data

You can connect to any of the databases and add more data:

```sql
-- Add more users
INSERT INTO users (email, first_name, last_name) 
SELECT 
    'user' || generate_series || '@example.com',
    'First' || generate_series,
    'Last' || generate_series
FROM generate_series(6, 100);

-- Add more events
INSERT INTO events (user_id, event_type, event_data, session_id)
SELECT 
    (random() * 5)::int + 1,
    (ARRAY['page_view', 'click', 'purchase', 'add_to_cart'])[floor(random() * 4 + 1)],
    '{"test": true}'::jsonb,
    'sess_' || generate_series
FROM generate_series(1, 1000);
```

## Troubleshooting

**Can't connect from PeerDB:**
- Ensure demo databases are on the same Docker network: `peerdb_network`
- Check if ports are accessible: `docker port demo-source-1`
- Try using `host.docker.internal` if PeerDB is in Docker

**No data syncing:**
- Check mirror status: `SELECT * FROM peerdb_mirror_status('mirror_name');`
- Check flow-worker logs: `docker logs flow-worker`
- Verify peer credentials are correct

**Port conflicts:**
- Change ports in `docker-compose-demo-dbs.yml` if 5433-5435 are in use

## Next Steps

1. Try syncing between different source and destination combinations
2. Experiment with different mirror configurations
3. Test schema changes and how PeerDB handles them
4. Try query replication patterns
5. Explore the Web UI at http://localhost:3000

Happy syncing! 🚀

