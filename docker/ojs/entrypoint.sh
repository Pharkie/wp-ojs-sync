#!/bin/bash
# OJS config templating — generates config.inc.php from environment variables.
# Wraps the PKP Docker image entrypoint.
set -e

CONFIG=/var/www/html/config.inc.php
TEMPLATE=/etc/ojs/config.inc.php.tmpl

# Generate config from template if not already installed
if [ ! -f "$CONFIG" ] || grep -q "installed = Off" "$CONFIG"; then
  echo "[SEA] Generating config.inc.php from template..."
  envsubst < "$TEMPLATE" > "$CONFIG"
  chown apache:apache "$CONFIG"
  chmod 640 "$CONFIG"
fi

# Run original entrypoint
exec /usr/local/bin/docker-entrypoint.sh "$@"
