#!/bin/bash
set -e

echo "🚀 Starting PeerDB Demo Databases..."

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Ensure the demo databases are on the same network as PeerDB
echo "📦 Ensuring Docker network exists..."
docker network create peerdb_network 2>/dev/null || true

# Start the demo databases
echo "🐘 Starting demo PostgreSQL databases..."
docker compose -f docker-compose-demo-dbs.yml up -d

# Wait for databases to be ready
echo "⏳ Waiting for databases to be ready..."
sleep 5

# Check if databases are running
if docker ps | grep -q "demo-source-1\|demo-source-2\|demo-dest"; then
    echo "✅ Demo databases are running!"
    echo ""
    echo "📊 Database Information:"
    echo "  • E-commerce (Source 1): localhost:5433"
    echo "  • Analytics (Source 2): localhost:5434"
    echo "  • Warehouse (Destination): localhost:5435"
    echo ""
    echo "🔗 Connection strings:"
    echo "  E-commerce:  psql 'port=5433 host=localhost user=postgres password=postgres dbname=ecommerce'"
    echo "  Analytics:   psql 'port=5434 host=localhost user=postgres password=postgres dbname=analytics'"
    echo "  Warehouse:   psql 'port=5435 host=localhost user=postgres password=postgres dbname=warehouse'"
    echo ""
    echo "📝 Next steps:"
    echo "  1. Connect to PeerDB: psql 'port=9900 host=localhost password=peerdb'"
    echo "  2. Create peers for these databases (see README.md)"
    echo "  3. Create mirrors to sync data"
    echo ""
    echo "To stop: docker compose -f docker-compose-demo-dbs.yml down"
else
    echo "❌ Failed to start demo databases. Check logs:"
    docker compose -f docker-compose-demo-dbs.yml logs
    exit 1
fi

