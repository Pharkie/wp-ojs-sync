# Architecture Decision

Last updated: 2026-02-16

## Decision trail

This document records what we investigated, what we found, and why options were eliminated. The goal is to make the reasoning traceable so future decisions don't re-cover the same ground.

### Step 1: Original plan — WP pushes subscriptions to OJS via REST API

The initial idea was simple: when someone becomes a SEA member on WordPress, a WP plugin calls the OJS REST API to create a matching subscription. OJS paywall sees the subscription and grants access. Non-member purchases through OJS are unaffected.

**Result: Dead.** The OJS REST API has no subscription endpoints. Not in 3.4, not in 3.5, not on the main branch. Zero. Confirmed via the [swagger spec](https://github.com/pkp/ojs/blob/main/docs/dev/swagger-source.json), [PKP community forums](https://forum.pkp.sfu.ca/t/are-there-api-or-other-options-for-subscription-management-available-in-ojs-3-3/86106), and GitHub issues. PKP has said this is "not a development priority."

The user creation API is also questionable — the swagger spec shows read-only endpoints (GET only, no POST). Some older docs suggest POST /users exists but this is unconfirmed on current versions.

See `phase0-findings.md` for full research.

### Step 2: Subscription SSO plugin — could OJS ask WP instead?

Since we can't push subscriptions TO OJS, we considered flipping the model: instead of WP pushing data, OJS pulls verification FROM WP at access time. The [Subscription SSO plugin](https://github.com/asmecher/subscriptionSSO) (maintained by PKP's lead developer) does exactly this.

We initially rejected this as part of a category ("SSO plugins are fragile"). But this plugin is not OIDC/OpenID — it's a simpler redirect-and-verify flow. So we read the actual source code to evaluate it properly.

**What it actually does (from source code):**

1. User hits a paywalled article on OJS
2. OJS checks its own subscriptions first — if the user already has one, the plugin does nothing
3. If not subscribed AND no valid SSO session → plugin **redirects the user's browser** to WordPress
4. WordPress authenticates them, confirms membership, generates a token
5. WordPress redirects them back to OJS with that token in the URL
6. OJS makes a server-side cURL call to a WP verification endpoint with the token
7. If WP's response matches a configured regex → OJS stores a timestamp in the PHP session
8. User can browse paywalled content for N hours (configurable) without re-verification
9. After the session expires, the cycle repeats

**Result: Dead.** The plugin hijacks the purchase flow. Here's the critical code path:

```
User hits paywalled content
  → OJS checks own subscriptions → not subscribed
  → Plugin checks SSO session → no valid session
  → Plugin IMMEDIATELY REDIRECTS to WordPress
  → OJS never shows its purchase/paywall page
```

If a non-member wants to buy a single article for £3, they get bounced to WordPress instead of seeing OJS's "buy this article" page. The plugin assumes WordPress IS the only subscription system. There is no fallback to "show OJS purchase options if SSO also says no."

This breaks a hard requirement: non-members must be able to buy individual articles (£3), current issues (£25), and back issues (£18) through OJS. The Subscription SSO plugin makes that impossible.

See `phase0-sso-plugin-audit.md` for the full source code analysis.

### Step 3: What's left

With the REST API approach dead and the SSO plugin incompatible with OJS purchases, three options remain:

---

## Option B: Custom OJS Plugin + WP Plugin (RECOMMENDED)

**Status: Recommended.** This is the cleanest viable approach.

### The idea

OJS has complete internal PHP classes for subscription management (`IndividualSubscriptionDAO` with full CRUD). The problem is just that these classes have no HTTP interface. So we build a small OJS plugin that exposes them as REST API endpoints, and a WP plugin that calls those endpoints.

### How it works

```
Member signs up / renews on WordPress
  → WP plugin fires on membership status change
  → Calls OJS custom endpoint: find-or-create user by email
  → Calls OJS custom endpoint: create/renew subscription
  → OJS paywall sees valid subscription → grants access normally

Member lapses / cancels
  → WP plugin fires
  → Calls OJS custom endpoint: expire/delete subscription
  → OJS paywall denies access → shows normal purchase options

Non-member visits paywalled content
  → No subscription exists
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

### Trade-offs

- **Two plugins to build and maintain.** More initial work than a simpler approach.
- **Requires OJS 3.5+** for clean plugin API. On 3.4, plugin endpoint registration is much harder (older `LoadHandler` hook pattern). If SEA is on 3.4, consider Option C as a stopgap.
- **Members need separate OJS accounts.** Two logins. Matched by email address. Need clear onboarding to explain this.
- **OJS upgrades could break the OJS plugin.** Mitigated by using the DAO layer (more stable than raw SQL), but still needs testing on each OJS upgrade.
- **Effort:** 2-4 weeks for both plugins.

### Blocking questions

| Question | Why it matters |
|---|---|
| OJS version (3.4.x vs 3.5.x)? | 3.5+ required for clean plugin API |
| Can we install OJS plugins? | Required — the OJS plugin is half the solution |
| Which WP membership plugin? | Determines WP hook points |
| Which membership tiers grant journal access? | Scope of the sync logic |
| OJS admin access available? | Needed for plugin install and API key setup |

---

## Option C: Direct DB Writes (FALLBACK)

**Status: Fallback.** Use only if OJS plugins can't be installed, or as a stopgap while building Option B.

### The idea

Skip the API layer entirely. WP plugin connects directly to the OJS database and writes subscription records.

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
- Same membership hooks as Option B
- Direct database connection to OJS (PDO or wpdb with external connection)
- Writes to `users`, `subscriptions`, `subscription_types` tables
- Must match exact OJS schema expectations

### Why you might use this

- No OJS plugin installation required
- Works on any OJS version (3.4, 3.5, whatever)
- Faster to build (1-2 weeks)
- Only one plugin to maintain

### Why it's risky

- **Bypasses OJS validation, hooks, and event system.** If OJS expects certain things to happen when a subscription is created (notifications, cache invalidation, etc.), they won't.
- **Schema changes between OJS versions break it silently.** An OJS upgrade could change column names, add required fields, or restructure tables. The plugin won't know until things fail.
- **No audit trail.** OJS won't log subscription creation events because they didn't go through OJS.
- **Requires database access.** WP server must be able to connect to the OJS database. If they're on different servers, this means cross-server DB access or SSH tunnels.
- **Hard to debug.** When something goes wrong, neither OJS logs nor WP logs will have the full picture.

### When to use

- OJS is on 3.4 and can't be upgraded (Option B won't work cleanly)
- Can't install OJS plugins for some reason
- Need something shipping immediately while Option B is being built
- WP and OJS share a database server

---

## Option D: Janeway Migration (NUCLEAR)

**Status: Last resort.** Only if all OJS options prove unworkable.

Abandon OJS entirely. Migrate to [Janeway](https://janeway.systems/) (Python/Django, proper OAuth, good APIs). Build a custom paywall since Janeway ideologically refuses to support them.

**Only consider if:**
- OJS plugin development proves impossible or disproportionately expensive
- OJS version is locked to 3.4 with no upgrade path AND direct DB writes are unacceptable
- The total cost of OJS integration exceeds the cost of platform migration + custom paywall

**Effort:** Weeks to months. Content migration, paywall development, new hosting, staff retraining.

---

## Eliminated options

| Option | Why eliminated |
|---|---|
| **OJS REST API sync** | API doesn't exist. No subscription endpoints in any OJS version. |
| **Subscription SSO plugin** | Hijacks OJS purchase flow. Non-members can't buy articles/issues. Incompatible with SEA's requirement for per-item sales. |
| **OIDC / OpenID SSO** | Only solves authentication, not authorization. OJS plugin poorly maintained against 3.5 breaking changes. If it fails, nobody can log into OJS. |

---

## Recommendation

**Ship Option B** (custom OJS plugin + WP plugin). It's more work than we'd like, but it's the only approach that:
- Keeps OJS purchases working for non-members
- Creates proper subscription records in OJS
- Doesn't bypass OJS's validation layer
- Uses standard plugin architecture on both sides

If OJS is stuck on 3.4 and can't upgrade, start with **Option C** (direct DB) as a stopgap, and plan to migrate to Option B when OJS is upgraded to 3.5+.
