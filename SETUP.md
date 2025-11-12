# PeerDB Setup Guide

## Quick Start

### 1. Run PeerDB

```bash
# Run PeerDB in Docker (uses pre-built images)
bash ./run-peerdb.sh

# OR for local development (rebuilds from local code)
bash ./generate-protos.sh  # First time only - requires buf and go
bash ./dev-peerdb.sh
```

### 2. Connect to PeerDB

```bash
# Use psql (version >=14.0)
psql "port=9900 host=localhost password=peerdb"
```

### 3. Setup Demo Databases

```bash
# Start demo PostgreSQL databases
cd demo-databases
docker compose -f docker-compose-demo-dbs.yml up -d

# Wait a few seconds for databases to initialize
sleep 5
```

### 4. Access Demo Databases

**From Host:**
- `demo-source-1` (ecommerce): `localhost:5433`
- `demo-source-2` (analytics): `localhost:5434`
- `demo-dest`: `localhost:5435`

**From PeerDB Containers:**
- Use container names: `demo-source-1`, `demo-source-2`, `demo-dest` with port `5432`
- Or use `host.docker.internal` with host ports: `5433`, `5434`, `5435`

**Connection Details:**
- User: `postgres`
- Password: `postgres`
- Databases: `ecommerce`, `analytics`, `postgres`

### 5. Create Peers in PeerDB

```sql
-- From PeerDB (port 9900)
CREATE PEER ecommerce_source FROM POSTGRES WITH (
    host = 'demo-source-1',  -- Container name (if PeerDB is in Docker)
    port = '5432',
    user = 'postgres',
    password = 'postgres',
    database = 'ecommerce'
);

CREATE PEER analytics_source FROM POSTGRES WITH (
    host = 'demo-source-2',
    port = '5432',
    user = 'postgres',
    password = 'postgres',
    database = 'analytics'
);

CREATE PEER dest FROM POSTGRES WITH (
    host = 'demo-dest',
    port = '5432',
    user = 'postgres',
    password = 'postgres',
    database = 'postgres'
);
```

## Requirements

- Docker and Docker Compose
- For local development: `buf` and `go` (see installation below)

## Installing Dependencies (Ubuntu)

### Install buf (protobuf compiler)

```bash
curl -sSL "https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-x86_64" -o ~/.local/bin/buf
chmod +x ~/.local/bin/buf
export PATH="$HOME/.local/bin:$PATH"
```

### Install Go

```bash
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
tar -C ~/.local -xzf go1.21.5.linux-amd64.tar.gz
export PATH="$HOME/.local/go/bin:$PATH"
export GOROOT="$HOME/.local/go"
```

### Install psql (PostgreSQL client)

```bash
sudo apt install postgresql-client-common
```

## Web UI

Access PeerDB UI at: http://localhost:3000

## Stopping Services

```bash
# Stop PeerDB
docker compose down

# Stop demo databases
cd demo-databases
docker compose -f docker-compose-demo-dbs.yml down
```

## Complete Clean Slate Rebuild

To completely recreate everything (PeerDB and demo databases) from scratch:

```bash
# From the project root directory
docker compose -f docker-compose-dev.yml down -v && \
cd demo-databases && \
docker compose -f docker-compose-demo-dbs.yml down -v && \
cd .. && \
bash ./generate-protos.sh && \
bash ./dev-peerdb.sh & \
sleep 10 && \
cd demo-databases && \
docker compose -f docker-compose-demo-dbs.yml up -d
```

**What this does:**
- Stops and removes all PeerDB containers and volumes (`-v` removes all data)
- Stops and removes all demo database containers and volumes
- Regenerates protobuf files
- Rebuilds and starts PeerDB from local code
- Recreates demo databases with fresh data

**Note**: This deletes all data. Use this when you want a completely fresh start.

**After running this**: You may need to create the Temporal search attribute (see Troubleshooting section below).

## Troubleshooting

### Temporal Search Attribute Error

**Error**: `unable to start PeerFlow workflow: Namespace default has no mapping defined for search attribute MirrorName`

**What it is**: 
Temporal uses search attributes to index and query workflows. The `MirrorName` attribute allows PeerDB to search for workflows by mirror name. This is a required search attribute that must be registered with Temporal before workflows can use it.

**Why it happens**:
- When containers are recreated, Temporal starts fresh and doesn't have the search attribute registered
- The initialization script (`mirror-name-search.sh`) should create this automatically, but it may not run if:
  - The Temporal admin tools container starts before Temporal is fully ready
  - The script hasn't executed yet
  - Containers were restarted and the script didn't run

**How to fix**:

1. **Wait a few seconds** after starting containers - the script may create it automatically
2. **If it still fails, manually create the search attribute**:
   ```bash
   docker exec temporal-admin-tools temporal operator search-attribute create --name MirrorName --type Text --namespace default
   ```

3. **Verify it was created**:
   ```bash
   docker exec temporal-admin-tools temporal operator search-attribute list --namespace default | grep MirrorName
   ```

   You should see `MirrorName` listed as type `Text`.

**After fixing**: Try creating your mirror again. The error should be resolved.

**Note**: This is a one-time setup per Temporal namespace. Once created, it persists until you recreate the Temporal database/volumes.

