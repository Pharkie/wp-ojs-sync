# Architecture Decision

Last updated: 2026-02-16

## Naming

We use the previous developer's naming convention:
- **Plan A** — OIDC/OpenID SSO (eliminated)
- **Plan B** — Subscription SSO plugin (eliminated)
- **Plan C** — WP pushes subscription changes to OJS via plugins on each side (recommended)
- **Plan C-fallback** — Direct DB writes (degraded version of Plan C, no OJS plugin)
- **Plan D** — Janeway migration (nuclear option)

## Decision trail

This document records what we investigated, what we found, and why options were eliminated. The goal is to make the reasoning traceable so future decisions don't re-cover the same ground.

### Step 1: Plan A — OIDC/OpenID SSO

The previous developer evaluated this thoroughly. The OJS OIDC client plugin has multiple unresolved bugs (mid-teens), reports of fatal errors on multi-journal setups, and no production-ready release for OJS 3.5 months after 3.5's release. Even if it worked, the maintenance burden would be huge — potentially breaking OJS login entirely after every major update.

Additionally, OIDC only solves authentication (who is this person?), not authorization (do they have a subscription?). You'd still need a separate mechanism to sync subscriptions.

**Result: Eliminated.** Previous developer confirmed independently. We concur.

### Step 2: Plan B — Subscription SSO plugin

The previous developer rejected this for good reasons (complexity, fights with paywall, janky user flow). We initially reconsidered it because it looked simpler than originally understood — but then we read the actual source code.

**What it actually does (from [source code audit](./phase0-sso-plugin-audit.md)):**

1. User hits a paywalled article on OJS
2. OJS checks its own subscriptions first — if the user already has one, the plugin does nothing
3. If not subscribed AND no valid SSO session → plugin **redirects the user's browser** to WordPress
4. WordPress authenticates them, confirms membership, generates a token
5. WordPress redirects them back to OJS with that token in the URL
6. OJS makes a server-side cURL call to a WP verification endpoint with the token
7. If WP's response matches a configured regex → OJS stores a timestamp in the PHP session
8. User can browse paywalled content for N hours (configurable) without re-verification

**Result: Eliminated.** The plugin hijacks the purchase flow:

```
User hits paywalled content
  → OJS checks own subscriptions → not subscribed
  → Plugin checks SSO session → no valid session
  → Plugin IMMEDIATELY REDIRECTS to WordPress
  → OJS never shows its purchase/paywall page
```

Non-members who want to buy a £3 article get bounced to WordPress instead of seeing OJS's purchase page. The plugin assumes WordPress IS the only subscription system. There is no fallback to "show OJS purchase options if SSO also says no."

This breaks a hard requirement: non-members must be able to buy individual articles (£3), current issues (£25), and back issues (£18) through OJS.

### Step 3: Original REST API idea — WP pushes subscriptions via OJS API

The initial idea behind Plan C was simple: WP calls OJS REST API to create subscriptions. The previous developer believed this was feasible using "core API endpoints."

**Result: Partially wrong.** The OJS REST API has no subscription endpoints. Not in 3.4, not in 3.5, not on main. Confirmed via the [swagger spec](https://github.com/pkp/ojs/blob/main/docs/dev/swagger-source.json), [PKP forums](https://forum.pkp.sfu.ca/t/are-there-api-or-other-options-for-subscription-management-available-in-ojs-3-3/86106), and GitHub issues. PKP has said this is "not a development priority." The user creation API is also questionable — swagger spec shows read-only endpoints.

However: OJS has complete internal PHP classes for subscription CRUD (`IndividualSubscriptionDAO`). They just have no HTTP interface. **The fix is a small OJS plugin that exposes these classes as REST endpoints.** This keeps the spirit of Plan C intact — the WP side is the same, we just need to build the OJS receiving end ourselves.

See `phase0-findings.md` for full API research.

---

## Plan C: Custom OJS Plugin + WP Plugin (RECOMMENDED)

**Status: Recommended.** This is the previous developer's Plan C, with one addition: a small OJS plugin to expose the subscription API that OJS doesn't ship natively.

### How it works (push model)

```
Member signs up / renews on WordPress
  → WP plugin fires on membership status change
  → Calls OJS custom endpoint: find-or-create user by email
  → Calls OJS custom endpoint: create/renew subscription
  → Subscription record now exists in OJS database
  → Later, when member visits OJS and hits paywalled content:
  → OJS paywall checks its own database → finds valid subscription → grants access

Member lapses / cancels
  → WP plugin fires
  → Calls OJS custom endpoint: expire/delete subscription
  → OJS paywall denies access → shows normal purchase options

Non-member visits paywalled content
  → No subscription exists in OJS
  → OJS shows standard purchase page (£3 / £25 / £18)
  → Completely unaffected by the integration
```

### What gets built

**OJS plugin** (`sea-subscription-api`) — installed in `plugins/generic/seaSubscriptionApi/`:
- Registers REST endpoints for subscription CRUD
- Uses OJS's own `IndividualSubscriptionDAO` internally (the classes already exist and are well-tested)
- Authenticated via OJS API key (Bearer token)
- No modifications to OJS core code — standard plugin, dropped into a folder
- Requires OJS 3.5+ for the clean plugin API pattern ([pkp-lib #9434](https://github.com/pkp/pkp-lib/issues/9434))

**WP plugin** (`sea-ojs-sync`) — installed like any WP plugin:
- Settings page: OJS URL, API key, subscription type ID mapping
- Hooks into WP membership plugin events (signup, renewal, lapse, cancellation)
- Calls OJS plugin endpoints on each event
- Bulk sync command (WP-CLI or admin button) for initial population and drift correction
- Error logging visible in WP admin
- Retry logic for failed API calls

### Why this works

- OJS paywall operates completely normally — subscriptions are real OJS subscription records
- Non-member purchases are completely unaffected
- WP remains source of truth — OJS subscriptions are a downstream projection
- Uses OJS's own validated DAO layer — no raw SQL, no bypassed validation
- Both sides are standard plugins — no core code changes on either platform
- Subscriptions visible in OJS admin UI for troubleshooting
- Scales to multiple journals easily

### Trade-offs

- **Two plugins to build and maintain.** More initial work than a simpler approach.
- **Requires OJS 3.5+.** SEA is currently on 3.4.0-9, so upgrade is required first.
- **Members need separate OJS accounts.** Two logins. Matched by email address. Need clear onboarding to explain this.
- **OJS upgrades could break the OJS plugin.** Mitigated by using the DAO layer (more stable than raw SQL), but still needs testing on each OJS upgrade.
- **Effort:** 2-4 weeks for both plugins, after OJS upgrade.

### Blocking questions

| Question | Status |
|---|---|
| OJS version? | **3.4.0-9.** Upgrade to 3.5 required. |
| Can we install OJS plugins? | Need to confirm |
| Which WP membership plugin? | Need from SEA |
| Which membership tiers grant journal access? | Need from SEA |
| OJS admin access available? | Need to confirm |

---

## Plan C-fallback: Direct DB Writes

**Status: Fallback only.** Use if OJS plugins can't be installed, or as a stopgap.

Same push model as Plan C, but instead of the OJS plugin receiving API calls, the WP plugin writes directly to the OJS database.

### How it works

```
WP membership change
  → WP plugin connects to OJS database
  → Finds or creates user in `users` table
  → INSERT/UPDATE/DELETE on `subscriptions` table
  → OJS reads subscriptions normally — doesn't know they were created externally
```

### What gets built

**WP plugin only** — nothing on OJS side:
- Same membership hooks as Plan C
- Direct database connection to OJS (PDO or wpdb with external connection)
- Writes to `users`, `subscriptions`, `subscription_types` tables
- Must match exact OJS schema expectations

### Why it's risky

- **Bypasses OJS validation, hooks, and event system.** Notifications, cache invalidation, etc. won't fire.
- **Schema changes between OJS versions break it silently.** An OJS upgrade could change the tables without warning.
- **No audit trail.** OJS won't log subscription creation events.
- **Requires database access.** WP server must connect to OJS database.
- **Hard to debug.** Neither system has the full picture when things go wrong.

### When to use

- Can't install OJS plugins for some reason
- Need something shipping immediately while Plan C proper is being built
- WP and OJS share a database server

---

## Plan D: Janeway Migration (NUCLEAR)

**Status: Last resort.** Only if all OJS options prove unworkable.

Abandon OJS entirely. Migrate to [Janeway](https://janeway.systems/) (Python/Django, proper OAuth, good APIs). Build a custom paywall since Janeway ideologically refuses to support them.

**Only consider if:**
- OJS plugin development proves impossible or disproportionately expensive
- The total cost of OJS integration exceeds the cost of platform migration + custom paywall

**Effort:** Weeks to months. Content migration, paywall development, new hosting, staff retraining.

---

## Eliminated options

| Plan | Why eliminated |
|---|---|
| **Plan A** (OIDC/OpenID SSO) | Only solves login, not access. OJS plugin has unresolved bugs, no 3.5 release, breaks multi-journal. Previous developer confirmed. |
| **Plan B** (Subscription SSO plugin) | Source code audit confirmed it hijacks OJS purchase flow. Non-members can't buy articles/issues. See `phase0-sso-plugin-audit.md`. |
| **Native REST API sync** | OJS has no subscription API endpoints in any version. Plan C works around this with a custom OJS plugin. |

---

## Recommendation

**Ship Plan C** (custom OJS plugin + WP plugin), preceded by an OJS 3.4 → 3.5 upgrade.

Sequence:
1. Upgrade OJS to 3.5
2. Build and deploy OJS plugin (`sea-subscription-api`)
3. Build and deploy WP plugin (`sea-ojs-sync`)
4. Bulk sync existing members
5. Add cosmetic OJS template changes ("set your password" prompts, "subscribe via SEA" links)
