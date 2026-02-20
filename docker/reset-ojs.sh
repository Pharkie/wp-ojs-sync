#!/bin/bash
# Reset OJS to a clean state. Config is generated from template by entrypoint.
# Usage: ./docker/reset-ojs.sh
set -e

cd "$(dirname "$0")/.."

echo "==> Stopping containers..."
docker compose down

echo "==> Removing OJS data volume (code + config)..."
docker volume rm wpojs_ojs_data 2>/dev/null || true

echo "==> Removing OJS files volume..."
docker volume rm wpojs_ojs_files 2>/dev/null || true

echo "==> Starting containers..."
docker compose up -d

echo "==> Waiting for OJS database to be healthy..."
until docker compose exec ojs-db mariadb -u root -p"${OJS_DB_ROOT_PASSWORD:-devroot123}" -e "SELECT 1" >/dev/null 2>&1; do
    sleep 2
done

echo "==> Resetting OJS database..."
docker compose exec ojs-db mariadb -u root -p"${OJS_DB_ROOT_PASSWORD:-devroot123}" -e "DROP DATABASE IF EXISTS ojs; CREATE DATABASE ojs;"

echo "==> Restarting OJS (entrypoint will generate config from template)..."
docker compose restart ojs

echo "==> Waiting for OJS to respond..."
until curl -s -o /dev/null http://localhost:8081; do
    sleep 2
done

echo "==> OJS reset complete."
echo "    URL:   http://localhost:8081"
echo "    Config generated from docker/ojs/config.inc.php.tmpl"
echo "    Complete install via browser, then run: docker compose exec ojs bash /scripts/setup-ojs.sh"
