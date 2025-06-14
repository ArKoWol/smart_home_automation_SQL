#!/bin/bash
set -e

echo "Starting Smart Home System..."

command -v docker >/dev/null 2>&1 || { echo "Install Docker"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "Install Docker Compose"; exit 1; }

docker-compose down -v --remove-orphans >/dev/null 2>&1 || true
docker-compose up -d

echo "Waiting for databases..."
sleep 30

# Проверка готовности OLTP
echo "Checking OLTP database..."
for i in {1..10}; do
    if docker exec smart_home_shop_oltp psql -U postgres -d smart_home_shop_oltp -c "SELECT 1;" >/dev/null 2>&1; then
        echo "OLTP ready"
        break
    fi
    echo "Waiting for OLTP... ($i/10)"
    sleep 2
done

# Проверка готовности OLAP
echo "Checking OLAP database..."
for i in {1..10}; do
    if docker exec smart_home_shop_olap psql -U postgres -d smart_home_shop_olap -c "SELECT 1;" >/dev/null 2>&1; then
        echo "OLAP ready"
        break
    fi
    echo "Waiting for OLAP... ($i/10)"
    sleep 2
done

# Настройка соединения между базами
echo "Setting up connections..."
docker exec smart_home_shop_olap psql -U postgres -d smart_home_shop_olap -c "CREATE EXTENSION IF NOT EXISTS postgres_fdw;" >/dev/null 2>&1 || true

docker exec smart_home_shop_olap psql -U postgres -d smart_home_shop_olap -c "
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname = 'oltp_server') THEN
        CREATE SERVER oltp_server FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host 'smart_home_shop_oltp', port '5432', dbname 'smart_home_shop_oltp');
        CREATE USER MAPPING FOR postgres SERVER oltp_server
        OPTIONS (user 'postgres', password 'postgres');
    END IF;
END \$\$;
" >/dev/null 2>&1 || true

# Проверка данных
USERS=$(docker exec smart_home_shop_oltp psql -U postgres -d smart_home_shop_oltp -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ' || echo "0")
SALES=$(docker exec smart_home_shop_olap psql -U postgres -d smart_home_shop_olap -t -c "SELECT COUNT(*) FROM fact_sales;" 2>/dev/null | tr -d ' ' || echo "0")

echo "System started!"
echo "Data: $USERS users, $SALES sales"
echo "OLTP: localhost:5434 | OLAP: localhost:5433"
echo "User: postgres | Pass: postgres"
