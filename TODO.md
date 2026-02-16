# TODO — SEA WP ↔ OJS Integration

## Phase 0: Verify assumptions

### Answered by research (2026-02-16)

- [x] **Audit OJS REST API for subscription endpoints** — **NO subscription endpoints exist.** Not in 3.4, not in 3.5. The original REST API sync plan is not directly possible. See `docs/phase0-findings.md`.
- [x] **Confirm OJS API auth method** — Bearer token via `Authorization` header. Token per-user at Profile > API Key. Requires `api_key_secret` in `config.inc.php`. Apache+PHP-FPM needs `CGIPassAuth on`. Fallback: `?apiToken=` query param.
- [x] **Assess user creation via API** — Conflicting evidence. Swagger spec shows read-only user endpoints. **Must verify against actual OJS version.**
- [x] **Evaluate Subscription SSO plugin** — **Eliminated.** Source code audit confirmed it hijacks the OJS purchase flow. Non-members can't buy articles/issues while it's active. See `docs/phase0-sso-plugin-audit.md`.
- [x] **Evaluate OIDC/OpenID SSO** — **Eliminated.** Only solves login not access. OJS plugin has unresolved bugs, no production-ready release for 3.5, breaks multi-journal setups. Previous developer confirmed this independently.

### Still need from SEA (BLOCKING)

- [ ] **Confirm OJS version** — 3.4.x vs 3.5.x. 3.5+ required for clean OJS plugin API.
- [ ] **Confirm WP membership plugin** — which plugin? (WooCommerce Memberships, Paid Memberships Pro, MemberPress, custom?)
- [ ] **Map membership tiers** — which tiers exist? Which grant journal access? All of them?
- [ ] **Confirm hosting/network** — same server? Same database server? Firewall?
- [ ] **Get OJS admin access** — needed for plugin installation, API key setup, subscription type config
- [ ] **Confirm: can we install OJS plugins?** — required for the recommended approach

---

## Decision: Architecture

**Option B: Custom OJS Plugin + WP Plugin.** See `docs/architecture.md` for full reasoning and decision trail.

This is essentially the same approach the previous developer identified as "Plan C" — sync accounts and subscriptions from WP to OJS using OJS's built-in mechanisms, no SSO plugins, no OIDC, no password sync. The key difference from their original description: the OJS REST API doesn't have subscription endpoints out of the box, so we need a small OJS plugin to expose them. The WP side is the same.

Fallback: Option C (direct DB writes) if OJS plugins can't be installed or OJS is stuck on 3.4.

---

## Phase 1: Build it (unblocked once we have SEA answers above)

### OJS plugin (`sea-subscription-api`)

- [ ] Plugin skeleton: `plugins/generic/seaSubscriptionApi/`
- [ ] Register REST endpoints for subscription CRUD using OJS 3.5 plugin API pattern
- [ ] Endpoint: find user by email
- [ ] Endpoint: create user (if native API can't do this — verify first)
- [ ] Endpoint: create/renew individual subscription
- [ ] Endpoint: expire/delete subscription
- [ ] Endpoint: list subscriptions (for bulk sync verification)
- [ ] Authentication via OJS API key
- [ ] Test against real OJS instance

### WP plugin (`sea-ojs-sync`)

- [ ] Plugin skeleton
- [ ] Settings page: OJS URL, API key, subscription type ID mapping
- [ ] Core sync function: given a WP user + membership status → call OJS endpoints
- [ ] Hook into WP membership plugin events (signup, renewal, lapse, cancellation)
- [ ] Bulk sync command (WP-CLI or admin button) for initial population
- [ ] Error logging visible in WP admin
- [ ] Retry logic for failed API calls
- [ ] Test end-to-end

### OJS cosmetic changes

- [ ] "First time here from SEA? Set your password" message on login page
- [ ] "To subscribe, visit SEA" link on paywall page
- [ ] Launch email to existing members explaining OJS access

---

## Phase 2: Robustness (after Phase 1 ships)

- [ ] Scheduled reconciliation (nightly full sync to catch drift)
- [ ] Admin dashboard: sync status per member
- [ ] Email alerts on sync failures
- [ ] Rate limiting for bulk operations

## Phase 3: UX (nice to have)

- [ ] "Access journal" link on WP member dashboard
- [ ] Onboarding email for new members explaining OJS account
- [ ] Password reset flow documentation

---

## Open questions

1. ~~Can the OJS REST API manage subscriptions?~~ **No.**
2. ~~Does the Subscription SSO plugin coexist with purchases?~~ **No.**
3. Which WP membership plugin is in use? **(Need from SEA)**
4. What OJS version? **(Need from SEA)**
5. What happens to existing OJS users who are also SEA members? (Migration/dedup plan)
6. Are there members who need OJS access outside the standard membership? (editorial board, reviewers)
7. Does the OJS user creation API (POST /users) work on SEA's version? (Verify on real instance)

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| ~~OJS API lacks subscription endpoints~~ | — | — | **Confirmed.** Custom OJS plugin exposes them. |
| ~~SSO plugin conflicts with purchases~~ | — | — | **Confirmed.** Eliminated. |
| OJS version is 3.4 (no clean plugin API) | Medium | High | Fall back to Option C (direct DB) |
| User creation API doesn't exist | Medium | Medium | Custom OJS plugin handles this too |
| Sync failures silently drop members | Medium | High | Logging, nightly reconciliation, admin alerts |
| Members confused by two logins | High | Medium | Clear onboarding, strategic "set password" prompts |
| OJS upgrade breaks custom plugin | Medium | High | Use DAO layer (stable), test upgrades in staging |
| WP membership plugin changes | Low | Medium | Abstract hooks behind adapter |
