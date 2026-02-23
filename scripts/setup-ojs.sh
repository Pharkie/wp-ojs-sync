#!/bin/bash
# Bootstrap OJS: create journal, subscription type, enable plugin.
# Idempotent — safe to run repeatedly.
#
# Usage:
#   scripts/setup-ojs.sh                    # Base setup only
#   scripts/setup-ojs.sh --with-sample-data # Base setup + import 2 issues / 43 articles
#
# Run after OJS install:
#   docker compose exec ojs bash /scripts/setup-ojs.sh [--with-sample-data]
set -e

SAMPLE_DATA=false
for arg in "$@"; do
  case "$arg" in
    --with-sample-data) SAMPLE_DATA=true ;;
  esac
done

MARIADB="mariadb --skip-ssl -h${OJS_DB_HOST} -u${OJS_DB_USER} -p${OJS_DB_PASSWORD} ${OJS_DB_NAME}"

echo "[OJS] Setting up OJS..."

# --- Enable admin API key for scripted access ---
API_KEY_ENABLED=$($MARIADB -N -e "SELECT setting_value FROM user_settings WHERE user_id=1 AND setting_name='apiKeyEnabled'")
if [ "$API_KEY_ENABLED" != "1" ]; then
  echo "[OJS] Enabling API key for admin user..."

  # Generate a random API key
  API_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32)

  $MARIADB <<SQL
    INSERT INTO user_settings (user_id, locale, setting_name, setting_value)
    VALUES (1, '', 'apiKeyEnabled', '1')
    ON DUPLICATE KEY UPDATE setting_value='1';
    INSERT INTO user_settings (user_id, locale, setting_name, setting_value)
    VALUES (1, '', 'apiKey', '$API_KEY')
    ON DUPLICATE KEY UPDATE setting_value='$API_KEY';
SQL
else
  API_KEY=$($MARIADB -N -e "SELECT setting_value FROM user_settings WHERE user_id=1 AND setting_name='apiKey'")
fi

# Build JWT token: header.payload.signature using the api_key_secret from config
API_SECRET=$(grep "api_key_secret" /var/www/html/config.inc.php | head -1 | sed 's/.*= *//')
JWT_HEADER=$(echo -n '{"typ":"JWT","alg":"HS256"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
JWT_PAYLOAD=$(echo -n "[\"$API_KEY\"]" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
JWT_SIGNATURE=$(echo -n "${JWT_HEADER}.${JWT_PAYLOAD}" | openssl dgst -sha256 -hmac "$API_SECRET" -binary | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
JWT_TOKEN="${JWT_HEADER}.${JWT_PAYLOAD}.${JWT_SIGNATURE}"

# Helper function for authenticated API calls
ojs_api() {
  local METHOD=$1 URL=$2 DATA=$3
  curl -s -X "$METHOD" "http://localhost:80${URL}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    ${DATA:+-d "$DATA"}
}

# --- Journal creation via API ---
JOURNAL_PATH="${OJS_JOURNAL_PATH:-journal}"
JOURNAL_NAME="${OJS_JOURNAL_NAME:-My Journal}"

JOURNAL_EXISTS=$($MARIADB -N -e "SELECT COUNT(*) FROM journals WHERE path='$JOURNAL_PATH'")

if [ "$JOURNAL_EXISTS" = "0" ]; then
  echo "[OJS] Creating journal '$JOURNAL_PATH' via API..."

  RESULT=$(ojs_api POST "/index/api/v1/contexts" "{
    \"urlPath\": \"$JOURNAL_PATH\",
    \"name\": {\"en\": \"$JOURNAL_NAME\"},
    \"primaryLocale\": \"en\",
    \"supportedLocales\": [\"en\"],
    \"supportedSubmissionLocales\": [\"en\"],
    \"enabled\": true
  }")

  if echo "$RESULT" | grep -q "\"urlPath\":\"$JOURNAL_PATH\""; then
    echo "[OJS] Journal '$JOURNAL_PATH' created."
  else
    echo "[OJS] WARNING: Journal creation may have failed:"
    echo "$RESULT" | head -5
  fi
else
  echo "[OJS] Journal '$JOURNAL_PATH' already exists, skipping."
fi

# --- Subscription type ---
SUB_TYPE_EXISTS=$($MARIADB -N -e "SELECT COUNT(*) FROM subscription_types WHERE journal_id=1")

if [ "$SUB_TYPE_EXISTS" = "0" ]; then
  echo "[OJS] Creating subscription type..."
  # duration = NULL means non-expiring. OJS validates subscriptions by checking
  # (st.duration IS NULL OR (checkDate >= s.date_start AND checkDate <= s.date_end)).
  # With duration = NULL, subscriptions with date_end = NULL pass validation.
  # With duration = 365, OJS would require date_end to be set on every subscription.
  $MARIADB <<'SQL'
    INSERT INTO subscription_types (journal_id, cost, currency_code_alpha, duration, format, institutional, membership, disable_public_display, seq)
    VALUES (1, 0.00, 'GBP', NULL, 1, 0, 0, 1, 1);
SQL
  echo "[OJS] Subscription type created."
else
  # Fix existing type if it has a duration set (breaks non-expiring subscriptions).
  WRONG_DURATION=$($MARIADB -N -e "SELECT COUNT(*) FROM subscription_types WHERE journal_id=1 AND duration IS NOT NULL")
  if [ "$WRONG_DURATION" -gt "0" ]; then
    echo "[OJS] Fixing subscription type duration (NULL = non-expiring)..."
    $MARIADB -e "UPDATE subscription_types SET duration = NULL WHERE journal_id = 1"
  fi
  echo "[OJS] Subscription type already exists, skipping."
fi

# --- Enable WP-OJS plugin ---
JOURNAL_ID=$($MARIADB -N -e "SELECT journal_id FROM journals WHERE path='$JOURNAL_PATH'")
echo "[OJS] Enabling wpojs-subscription-api plugin for journal $JOURNAL_ID..."
$MARIADB <<SQL
  INSERT IGNORE INTO plugin_settings (plugin_name, context_id, setting_name, setting_value, setting_type)
  VALUES ('wpojssubscriptionapiplugin', $JOURNAL_ID, 'enabled', '1', 'bool');
SQL

# --- Enable subscription (paywall) mode ---
# publishingMode: 0 = open access, 1 = subscription, 2 = none.
# OJS won't enforce the paywall without this.
PUB_MODE=$($MARIADB -N -e "SELECT setting_value FROM journal_settings WHERE journal_id=$JOURNAL_ID AND setting_name='publishingMode'" 2>/dev/null)

if [ "$PUB_MODE" != "1" ]; then
  echo "[OJS] Setting publishing mode to 'Subscription'..."
  ojs_api PUT "/$JOURNAL_PATH/api/v1/contexts/$JOURNAL_ID" '{"publishingMode": 1}' > /dev/null
  echo "[OJS] Publishing mode set."
else
  echo "[OJS] Publishing mode already set to 'Subscription', skipping."
fi

echo "[OJS] OJS setup complete."

# --- Sample data (dev/staging only) ---
if [ "$SAMPLE_DATA" = true ]; then
  IMPORT_XML="/data/ojs-import-clean.xml"
  if [ ! -f "$IMPORT_XML" ]; then
    echo "[OJS] ERROR: Import XML not found at $IMPORT_XML"
    exit 1
  fi

  # Idempotent check: see if articles already exist
  ARTICLE_COUNT=$($MARIADB -N -e "SELECT COUNT(*) FROM publications WHERE submission_id > 0")
  if [ "$ARTICLE_COUNT" -gt "0" ]; then
    echo "[OJS] Articles already imported ($ARTICLE_COUNT publications), skipping."
  else
    echo "[OJS] Importing OJS content (2 issues, 43 articles)..."
    php /var/www/html/tools/importExport.php NativeImportExportPlugin import "$IMPORT_XML" "$JOURNAL_PATH"
    NEW_COUNT=$($MARIADB -N -e "SELECT COUNT(*) FROM publications WHERE submission_id > 0")
    echo "[OJS] Import complete. Publications: $NEW_COUNT"
  fi

  # Set issues to require subscription (access_status: 1 = open, 2 = subscription).
  # Without this, articles stay open access even when the journal is in subscription mode.
  # Runs every time (not just on fresh import) so re-running the script fixes issues that
  # were imported before paywall mode was configured.
  OPEN_ISSUES=$($MARIADB -N -e "SELECT COUNT(*) FROM issues WHERE journal_id=$JOURNAL_ID AND access_status != 2")
  if [ "$OPEN_ISSUES" -gt "0" ]; then
    echo "[OJS] Setting $OPEN_ISSUES issue(s) to require subscription..."
    $MARIADB -e "UPDATE issues SET access_status = 2 WHERE journal_id=$JOURNAL_ID"
    echo "[OJS] Issue access updated."
  fi
fi
