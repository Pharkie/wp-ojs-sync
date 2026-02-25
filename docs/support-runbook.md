# Support Runbook: WP-OJS Sync

Quick reference for support staff handling member access issues.

---

## Common scenarios

### "I can't access journal articles"

1. **Check WP subscription status** — WooCommerce → Subscriptions → search by email. Is the subscription `active`?
2. **Check sync log** — WP Admin → OJS Sync → Sync Log → search by email. Look for recent `activate` entries.
   - If last entry is `success`: the sync worked. Check OJS directly.
   - If last entry is `fail`: note the error, check OJS connectivity, retry (see below).
   - If no entries: the member's subscription status change may not have fired. Run manual sync (see below).
3. **Check OJS** — OJS Admin → Users & Roles → search by email. Is the user present? Check Subscriptions → Individual Subscriptions. Is the subscription `Active`?

### "I changed my email and lost access"

The sync plugin detects WP email changes and updates OJS automatically. If it didn't work:

1. Check the sync log for `email_change` entries.
2. If the new email already existed on OJS (409 conflict), the sync will have failed. Manually update the OJS user's email in OJS Admin → Users & Roles → Edit User.

### "I never received the welcome email"

1. Check OJS email configuration (SMTP relay, SPF/DKIM).
2. Resend via CLI: `wp ojs-sync sync --user=<email>` — this will re-trigger find-or-create (idempotent) and won't duplicate the user.
3. The member can also use OJS's "Forgot Password" link directly.

---

## WP-CLI commands

All commands must be run on the WP server (or via SSH). Prefix with `--allow-root` if running as root.

| Command | What it does |
|---|---|
| `wp ojs-sync test-connection` | Test connectivity to OJS (ping + preflight). Run this first. |
| `wp ojs-sync status` | Show sync stats: total synced, pending, failed, last reconciliation. |
| `wp ojs-sync sync --dry-run` | Preview what bulk sync would do (no changes). |
| `wp ojs-sync sync` | Run bulk sync for all active members. |
| `wp ojs-sync sync --user=<id or email>` | Sync a single member (sends welcome email if new). |
| `wp ojs-sync send-welcome-emails --dry-run` | Preview how many welcome emails would be sent. |
| `wp ojs-sync send-welcome-emails` | Send welcome emails to all synced users who haven't received one. |
| `wp ojs-sync reconcile` | Run reconciliation now (compare WP ↔ OJS, fix drift). |

---

## WP Admin pages

- **Settings**: WP Admin → OJS Sync → Settings. OJS URL, type mapping, test connection button.
- **Sync Log**: WP Admin → OJS Sync → Sync Log. Filterable by status, searchable by email.
- **Queue**: WP Admin → Tools → Scheduled Actions. Filter by group `wpojs-sync`.

---

## Retry a failed sync

### Single entry

1. Go to Sync Log → filter by `Status: fail`.
2. Click the **Retry** link on the failed entry's row.

### Bulk retry

1. Go to Sync Log → filter by `Status: fail`.
2. Check the entries you want to retry.
3. Select **Retry Selected** from the Bulk Actions dropdown → Apply.

### Manual sync (bypasses queue)

```bash
wp ojs-sync sync --user=<email>
```

This calls OJS directly (not through Action Scheduler) and reports the result immediately.

---

## Troubleshooting

### Test connection fails

| Result | Meaning | Fix |
|---|---|---|
| "OJS not reachable" | WP can't reach OJS server at all | Check OJS URL in settings, verify OJS is running, check firewall |
| "Access denied (IP not allowlisted)" | OJS is reachable but blocking WP's IP | Add WP server IP to OJS `config.inc.php` `[wpojs] allowed_ips` |
| "Authentication failed" | API key mismatch | Verify `WPOJS_API_KEY` in `wp-config.php` matches `api_key_secret` in OJS `config.inc.php` |
| "Incompatible" | OJS plugin API changed | Run OJS `/preflight` to see which checks failed. May need OJS plugin update. |

### Daily digest shows failures

The digest email fires once per day if there were any sync failures in the last 24 hours.

1. Check the Sync Log for the specific failures.
2. Most common causes: OJS was temporarily down (transient, will auto-retry), or a configuration change broke connectivity.
3. If failures are ongoing, run `wp ojs-sync test-connection` to diagnose.

### OJS API log

OJS Admin → Website → Plugins → WP-OJS Subscription API → Status. Shows recent API requests, config health checks, and sync stats. Log entries older than 30 days are automatically cleaned up.
