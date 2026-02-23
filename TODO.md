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

## End-to-end smoke tests

- [x] WCS subscription activate → OJS user + subscription created → paywall grants access
- [x] WCS expiry → OJS subscription expired → paywall denies access
- [ ] Non-member → purchase options displayed → purchase → access (needs browser)
- [x] WP email change → OJS email updated
- [x] Welcome email → API logic, dedup, idempotency (email transport is a deployment infra check, not a code smoke test)
- [x] OJS down → queued → OJS up → retried → synced
- [x] Bulk sync dry-run → full run → counts match (683/683)

### Playwright E2E browser tests (`e2e/`)

- [x] Sync lifecycle — WCS activate/expire → OJS subscription status
- [x] OJS login — synced user sets password + logs in
- [x] WP dashboard — My Account journal access widget (active + inactive)
- [x] OJS UI messages — login hint, footer, paywall hint

## Future improvements

- Rate limiting on OJS endpoints
- Differential reconciliation (compare counts before full scan)
- Follow-up email for members who haven't set OJS password
- Admin dashboard: per-member sync status
- API key rotation support
- On-hold grace period (configurable)
