# Support Runbook — Draft

Quick reference for SEA staff handling member queries about journal access.

---

## "I can't access the journal"

1. **Check their WP subscription** — WP Admin → WooCommerce → Subscriptions → search by email. Is the subscription active?
2. **Check their OJS account** — OJS Admin → Users → search by email. Do they have an account? Do they have an active subscription?
3. **If WP active but OJS missing/expired** — resync: `wp sea-ojs sync --user=<email>`
4. **If both look fine** — are they logged into OJS? Have they set their password?

## "I didn't get the setup email"

1. Ask them to check spam/junk
2. Resend: `wp sea-ojs send-welcome-emails --user=<email>`
3. If still nothing: check OJS email config is working (OJS Admin → Administration → Email)

## "I have an OJS account with a different email"

The two accounts are matched by email. Options:

1. **Easiest:** update their WP email to match their existing OJS email (if they prefer that one)
2. **Or:** update their OJS email via OJS Admin → Users → Edit, then resync from WP

Either way, both accounts need the same email address.

## "My password link expired"

Go to [OJS login URL] → click "Forgot your password?" → enter their email → new link sent.

## "I'm paying but the journal says I need to buy"

This means the sync hasn't run or has failed:

1. Check WP Admin → SEA OJS Sync → Sync Log — search by email, look for errors
2. If there's a failure: `wp sea-ojs sync --user=<email>` to retry
3. If there's nothing in the log: the hook may not have fired — same fix, manual sync

## Useful commands

| Command | What it does |
|---|---|
| `wp sea-ojs sync --user=<email>` | Sync one member now |
| `wp sea-ojs send-welcome-emails --user=<email>` | Resend welcome email to one member |
| `wp sea-ojs status` | Show overall sync health |
| `wp sea-ojs test-connection` | Check OJS is reachable and compatible |
