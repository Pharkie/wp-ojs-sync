#!/bin/bash
# Import a database snapshot into the current Docker environment.
# Usage: ./scripts/db-import.sh <wp|ojs> <snapshot.sql>
set -e

SERVICE=$1
SNAPSHOT=$2

if [ -z "$SERVICE" ] || [ -z "$SNAPSHOT" ]; then
  echo "Usage: $0 <wp|ojs> <snapshot.sql>"
  exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
  echo "Error: snapshot file not found: $SNAPSHOT"
  exit 1
fi

case $SERVICE in
  wp)  docker compose exec -T wp wp db import - --allow-root < "$SNAPSHOT" ;;
  ojs) docker compose exec -T ojs-db mariadb -u ojs -p"${OJS_DB_PASSWORD:-devpass123}" ojs < "$SNAPSHOT" ;;
  *)   echo "Usage: $0 <wp|ojs> <snapshot.sql>"; exit 1 ;;
esac

echo "Imported $SNAPSHOT into $SERVICE"
