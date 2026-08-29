#!/bin/bash
# Re-create the Actions secrets for Pharkie/sea-ojs-private after a delete+recreate.
#
# Every value is read from its real home at run time, so no secret is ever
# written into this file. Run --check first: it resolves all six WITHOUT
# touching GitHub, which is the thing you want to know before you delete a repo.
#
#   ./restore-secrets.sh --check    # resolve everything, set nothing
#   ./restore-secrets.sh            # resolve, then gh secret set each one
#
# Plain POSIX-ish bash on purpose — macOS ships bash 3.2, which has no
# associative arrays.
set -uo pipefail

REPO="${TARGET_REPO:-Pharkie/sea-ojs-private}"
BOX_IP="46.225.173.209"
CHECK=""
[ "${1:-}" = "--check" ] && CHECK=1

FAIL=0
report() { # report <name> <value> <source>
  if [ -z "$2" ]; then
    printf "  %-24s MISSING   (%s)\n" "$1" "$3"; FAIL=1
  else
    printf "  %-24s ok, %4s bytes   (%s)\n" "$1" "${#2}" "$3"
  fi
}

echo "Resolving the six secrets the remaining workflows actually use:"

# The replacement monitoring key. The OLD one goes with the repo — its private
# half only ever existed inside the secret. This one was generated and PROVEN
# against the box on 2026-08-29, before anything was deleted.
SSH_MONITOR_KEY=$(cat ~/.ssh/hetzner-monitor 2>/dev/null || true)
report SSH_MONITOR_KEY "$SSH_MONITOR_KEY" "~/.ssh/hetzner-monitor"

VPS_HOST="$BOX_IP"
report VPS_HOST "$VPS_HOST" "the box"

# OJS really does run on the box, so its own .env is the right source.
BOX_ENV=$(ssh sea-live 'set -a; . /opt/pharkie-ojs-plugins/.env; set +a; printf "%s\n" "$OJS_BASE_URL"' 2>/dev/null || true)
LIVE_OJS_URL=$(printf '%s' "$BOX_ENV" | sed -n 1p)
report LIVE_OJS_URL "$LIVE_OJS_URL" "box .env OJS_BASE_URL"

# 🛑 NOT the box's WP_HOME, which is the wp-staging mirror behind basic auth.
# These monitoring tests browse the LIVE community WordPress on Krystal, which
# is a different machine entirely (see the Hetzner-is-not-live-WP note). Taking
# WP_HOME off the box gives https://wp-staging.… and the two WP tests fail 401
# while everything else passes — which is exactly what happened on the first
# v2 monitoring run, 2026-08-29. The spec documents the right value in its own
# header, and 15 of 17 tests passing is the shape this mistake makes.
LIVE_WP_HOME="https://community.existentialanalysis.org.uk"
report LIVE_WP_HOME "$LIVE_WP_HOME" "the live community WP (NOT the box)"

# Heartbeat URLs from Better Stack itself rather than from a copy of a copy.
# 450611 = "SEA: Hourly monitoring", 450612 = "SEA: Daily monitoring".
BS_TOKEN=$(security find-generic-password -s sea-betterstack-api -w 2>/dev/null || true)
hb_url() {
  [ -z "$BS_TOKEN" ] && return 0
  curl -fsS -H "Authorization: Bearer $BS_TOKEN" \
    "https://uptime.betterstack.com/api/v2/heartbeats/$1" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["attributes"]["url"])' 2>/dev/null || true
}
BETTERSTACK_HB_HOURLY=$(hb_url 450611)
BETTERSTACK_HB_DAILY=$(hb_url 450612)
report BETTERSTACK_HB_HOURLY "$BETTERSTACK_HB_HOURLY" "Better Stack heartbeat 450611"
report BETTERSTACK_HB_DAILY  "$BETTERSTACK_HB_DAILY"  "Better Stack heartbeat 450612"

echo
if [ "$FAIL" -ne 0 ]; then
  echo "🛑 At least one value did not resolve. DO NOT DELETE THE REPOSITORY."
  exit 1
fi
echo "All six resolved."

if [ -n "$CHECK" ]; then
  echo "--check: nothing was written to GitHub."
  exit 0
fi

echo "Writing them to $REPO …"
for name in SSH_MONITOR_KEY VPS_HOST LIVE_OJS_URL LIVE_WP_HOME BETTERSTACK_HB_HOURLY BETTERSTACK_HB_DAILY; do
  eval "value=\$$name"
  printf '%s' "$value" | gh secret set "$name" -R "$REPO"
  echo "  set $name"
done
echo
echo "Now confirm the monitors actually run:"
echo "  gh workflow run monitor-daily.yml -R $REPO && sleep 45 && gh run list -R $REPO --limit 3"
