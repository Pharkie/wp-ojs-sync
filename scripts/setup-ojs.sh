#!/bin/bash
# Bootstrap OJS: create subscription type, enable plugin.
# Idempotent — safe to run repeatedly.
# Run after OJS install: docker compose exec ojs bash /scripts/setup-ojs.sh
set -e

echo "[SEA] Setting up OJS..."

# Check if journal already exists (idempotent)
JOURNAL_EXISTS=$(mariadb -h"$OJS_DB_HOST" -u"$OJS_DB_USER" -p"$OJS_DB_PASSWORD" "$OJS_DB_NAME" \
  -N -e "SELECT COUNT(*) FROM journals WHERE path='t1'")

if [ "$JOURNAL_EXISTS" = "0" ]; then
  echo "[SEA] WARNING: Journal 't1' does not exist."
  echo "[SEA] Journal creation requires the OJS admin UI — cannot be fully scripted."
  echo "[SEA] Create it manually at: \${OJS_BASE_URL}/index.php/index/admin/contexts"
fi

# Create subscription type if not exists
SUB_TYPE_EXISTS=$(mariadb -h"$OJS_DB_HOST" -u"$OJS_DB_USER" -p"$OJS_DB_PASSWORD" "$OJS_DB_NAME" \
  -N -e "SELECT COUNT(*) FROM subscription_types WHERE journal_id=1")

if [ "$SUB_TYPE_EXISTS" = "0" ]; then
  echo "[SEA] Creating subscription type..."
  mariadb -h"$OJS_DB_HOST" -u"$OJS_DB_USER" -p"$OJS_DB_PASSWORD" "$OJS_DB_NAME" <<'SQL'
    INSERT INTO subscription_types (journal_id, cost, currency_code_alpha, duration, format, institutional, membership, disable_public_display, sequence)
    VALUES (1, 0.00, 'GBP', 365, 1, 0, 0, 1, 1);
SQL
  echo "[SEA] Subscription type created."
else
  echo "[SEA] Subscription type already exists, skipping."
fi

# Enable SEA plugin
echo "[SEA] Enabling sea-subscription-api plugin..."
mariadb -h"$OJS_DB_HOST" -u"$OJS_DB_USER" -p"$OJS_DB_PASSWORD" "$OJS_DB_NAME" <<'SQL'
  INSERT IGNORE INTO plugin_settings (plugin_name, context_id, setting_name, setting_value, setting_type)
  VALUES ('seasubscriptionapiplugin', 0, 'enabled', '1', 'bool');
SQL

echo "[SEA] OJS setup complete."
