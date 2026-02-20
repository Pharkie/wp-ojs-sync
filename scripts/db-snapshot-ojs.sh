#!/bin/bash
# Export + sanitise OJS database.
# Usage: ./scripts/db-snapshot-ojs.sh [output-file]
set -e

OUTPUT=${1:-docker/snapshots/ojs-$(date +%Y%m%d).sql}
mkdir -p "$(dirname "$OUTPUT")"

echo "Exporting OJS database..."
docker compose exec -T ojs-db mariadb-dump -u ojs -p"${OJS_DB_PASSWORD:-devpass123}" ojs > "$OUTPUT"

echo "Sanitising emails and passwords..."
sed -i.bak "s/\([a-zA-Z0-9._%+-]*\)@[a-zA-Z0-9.-]*\.[a-zA-Z]*/sanitised@example.com/g" "$OUTPUT"
rm -f "${OUTPUT}.bak"

echo "Snapshot saved: $OUTPUT"
