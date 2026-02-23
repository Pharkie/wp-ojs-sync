# Roadmap

## Done

- OJS plugin (`wpojs-subscription-api`) — code complete, reviewed
- WP plugin (`wpojs-sync`) — code complete, reviewed
- Docker dev environment
- Member dashboard widget (WooCommerce My Account)
- UI messages (OJS login hint, paywall hint, footer)

## Before deploying to production

- [ ] Upgrade OJS to 3.5 (required for the plugin API)
- [ ] Set up transactional email relay on OJS server (SPF/DKIM/DMARC) — verify welcome email delivery end-to-end
- [ ] Configure WP settings: type mapping, manual roles, OJS URL
- [ ] Configure OJS `config.inc.php` `[wpojs]` section: allowed IPs, WP member URL, support email
- [ ] Create OJS subscription type and record the `type_id`
- [ ] Run `wp ojs-sync test-connection` to verify connectivity
- [ ] Run `wp ojs-sync sync --dry-run` to verify member resolution
- [ ] Run `wp ojs-sync sync` for bulk initial sync
- [ ] Run `wp ojs-sync send-welcome-emails` to invite members

## Post-deploy checks

- [ ] Non-member → purchase options displayed → purchase → access (requires OJS payment plugin configured with live gateway)
- [ ] Welcome email delivery end-to-end (requires SMTP/SPF/DKIM on production OJS)

## End-to-end smoke tests

- [x] WCS subscription activate → OJS user + subscription created → paywall grants access
- [x] WCS expiry → OJS subscription expired → paywall denies access
- [x] WP email change → OJS email updated
- [x] Welcome email → API logic, dedup, idempotency (email transport is a deployment infra check, not a code smoke test)
- [x] OJS down → queued → OJS up → retried → synced
- [x] Bulk sync dry-run → full run → counts match (683/683)

### Playwright E2E browser tests (`e2e/`)

- [ ] Sync lifecycle — WCS activate/expire → OJS subscription status
- [ ] OJS login — synced user sets password + logs in
- [ ] WP dashboard — My Account journal access widget (active + inactive)
- [ ] OJS UI messages — login hint, footer, paywall hint (2/3 pass: login hint + footer)
- [ ] Admin monitoring — Sync Log page stats, nonce, retry actions
- [ ] OJS API request logging — log table + `wpojs_created_by_sync` flag

**Blocking issues (11 of 14 tests fail):**

1. **Shell quoting — nested single quotes break `dockerExec`**: `wpCli` wraps PHP in single quotes (`eval '...$sub...'`), then `dockerExec` wraps the whole command in single quotes too. The `'\''` escape technique breaks out of quoting for content between the inner quotes, so `$sub`, `$product` etc. still get expanded by bash. Affects: sync-lifecycle, ojs-login, wp-dashboard (active), ojs-ui-messages (paywall), admin-monitoring (retry actions). Fix: either remove inner single quotes from `wpCli`/callers and let `dockerExec` handle all quoting, or pass commands via stdin/temp file instead of `bash -c`.
2. **`wpojs_api_log` table doesn't exist**: OJS plugin schema not installed in dev environment. Affects: ojs-api-log.spec.ts, partially admin-monitoring.spec.ts.
3. **`wpLogin` timeout**: `page.waitForURL(/wp-admin|my-account/)` times out for non-admin users. Affects: admin-monitoring (stats, nonce), wp-dashboard (non-member). Likely needs the password set via WP-CLI before login, or the regex doesn't match the actual redirect URL.

## Future improvements

- Rate limiting on OJS endpoints
- Differential reconciliation (compare counts before full scan)
- Follow-up email for members who haven't set OJS password
- Admin dashboard: per-member sync status
- API key rotation support
- On-hold grace period (configurable)
