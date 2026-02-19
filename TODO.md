# TODO — SEA WP ↔ OJS Integration

## Established facts

Confirmed during Phase 0 research (2026-02-16). Details in `docs/phase0-findings.md`, `docs/phase0-sso-plugin-audit.md`, `docs/discovery.md`.

| Fact | Detail |
|---|---|
| OJS version (live) | 3.4.0-9. Staging upgraded to 3.5.0.3. |
| OJS admin access | Yes. Site Administrator level. Can install plugins. |
| WP membership stack | Ultimate Member + WooCommerce + WooCommerce Subscriptions. See `docs/wp-integration.md`. |
| Membership tiers | All tiers grant journal access. Nine WP roles (six standard, three manual). |
| Hosting | Different servers. WP and OJS communicate over HTTP. |
| OJS state | Fresh install. Admin logins only, ~60 test articles, no existing member accounts. |
| OJS journals | One journal (*Existential Analysis*). |
| OJS self-registration | Enabled. Non-members need it for paywall purchases. |
| WP email uniqueness | Enforced at DB level. UM email changes require confirmation. |
| OJS API auth | Bearer token via `Authorization` header. Requires `api_key_secret` in `config.inc.php`. Apache+PHP-FPM needs `CGIPassAuth on`. |
| OJS subscription API | Does not exist. Custom plugin exposes subscription CRUD. |
| OJS user creation API | Unconfirmed — swagger shows read-only. Must verify on staging (Phase 0.75). |
| OIDC SSO | Eliminated. Only solves login not access. Plugin has unresolved bugs. |
| Subscription SSO plugin | Eliminated. Hijacks purchase flow. See `docs/phase0-sso-plugin-audit.md`. |
| XML user import | Eliminated. Creates accounts only, not subscriptions. See `docs/xml-import-evaluation.md`. |
| Manual member roles | Admin-assigned (Exco/life members). Grant OJS access but bypass WCS checkout — bulk sync must detect these directly. |
| Non-standard access | Editorial board, reviewers, etc. managed manually in OJS admin UI (Subscriptions > Individual Subscriptions). Not part of WP sync. |
| UM ↔ WCS relationship | UM handles profiles, WCS handles payments. Standard integration (assumed UM WooCommerce extension). WCS is the authority on subscription status. |
| OJS email | Assumed raw SMTP. Must set up transactional relay (Mailgun or similar) before bulk welcome email send. |

## Decision: Push-sync (plugins on each side)

**Push-sync: Custom OJS plugin + WP plugin.** See `docs/plan.md` for the implementation plan, `docs/discovery.md` for the decision trail, `docs/review-findings.md` for the six-perspective review that shaped the final spec.

---

## Phase 0.5: Upgrade OJS to 3.5

OJS 3.5.0 was released June 2025 (LTS). Required for the custom plugin API. This must happen before any plugin development.

- [x] **Confirm current OJS version** — **OJS 3.4.0-9** (confirmed via meta generator tag on live site)
- [x] **Confirm or create staging environment** — **Done.** Developer set up staging:
  - OJS staging: https://testojs.existentialanalysis.org.uk/
  - WP staging: https://testj.existentialanalysis.org.uk/
- [x] **Upgrade to 3.5 on staging** — **Done.** OJS staging is running **3.5.0.3** (confirmed 2026-02-19 via About page).
- [ ] **Post-upgrade acceptance criteria** (still need to verify on staging):
  - [ ] Journal content intact and browsable
  - [ ] Existing user accounts survived
  - [ ] Paywall active on paywalled articles
  - [ ] Non-member purchase flow works: visit paywalled article → see correct prices (£3/£25/£18) → complete test purchase → access granted
  - [ ] OJS admin UI functional
- [ ] **Write OJS 3.5 upgrade rollback runbook** — step-by-step: restore DB, restore files, verify 3.4 is back. Test the rollback on staging.
- [ ] **Agree go/no-go threshold with SEA** — if staging upgrade takes >X days to stabilise, escalate Janeway decision
- [ ] **Upgrade to 3.5 on production** (only after staging passes all acceptance criteria)

### Key 3.5 breaking changes to watch for
- Slim → Laravel routing (affects any existing custom code)
- `.inc.php` file suffixes no longer supported
- Non-namespaced plugins no longer supported
- Vue 2 → Vue 3 on frontend
- New `app_key` config required
- Locales now part of URLs

---

## Phase 0.6: Set up staging for testing

Staging sites are bare installs. Before plugin development or end-to-end testing, they need enough of the live site's membership infrastructure to be valid. This doesn't need to replicate the full live site — just enough to trigger WCS hooks and produce realistic sync payloads.

### WP staging (https://testj.existentialanalysis.org.uk/)

- [ ] **Install WooCommerce** + **WooCommerce Subscriptions**
- [ ] **Install Ultimate Member** (needed if UM ↔ WCS bridge plugin exists on live — see Phase 0.75 open question)
- [ ] **Create at least one WCS subscription product** — e.g. "Test SEA UK member" with a recurring subscription. Doesn't need real payment gateway — use WCS manual/test mode. One product is enough since all tiers grant the same OJS access.
- [ ] **Create test user accounts** (~5-10) with active subscriptions, so bulk sync has something to work with
- [ ] **Verify WCS hooks fire** — activate/expire a test subscription manually in WP admin, confirm `woocommerce_subscription_status_active` / `_expired` hooks fire (add temporary `error_log()` or use Query Monitor plugin)

### OJS staging (https://testojs.existentialanalysis.org.uk/)

- [ ] **Create a test journal** (or confirm one exists) with at least one paywalled article
- [ ] **Create a subscription type** — e.g. "SEA Member" individual subscription, online format, with a reasonable duration. Record the `type_id` — the WP plugin needs it for the mapping.
- [ ] **Enable paywall** — confirm that visiting the test article as a non-logged-in user shows purchase/login options, not free access
- [ ] **Configure `api_key_secret`** in `config.inc.php` `[security]` section (required for API auth)
- [ ] **Create dedicated service account** — purpose-built OJS account for API sync, with API key enabled (Profile > API Key)
- [ ] **Test Bearer token auth** — `curl -H "Authorization: Bearer <token>" https://testojs.existentialanalysis.org.uk/api/v1/users` from WP staging server. If 401, add `CGIPassAuth on` to `.htaccess`.

### What we DON'T need on staging

- Every WP membership role from the live site (one WCS product is enough)
- Real payment processing (WCS test/manual mode is fine)
- Full content library (one paywalled article is enough)
- Ultimate Member member directory or listing features
- GiveWP, SEO plugins, or other unrelated plugins

---

## Phase 0.75: Verify OJS API prerequisites

Must complete before writing any plugin code. Answered items have been moved to the established facts table above.

- [ ] **Test user creation API** — send `POST /api/v1/users` with a Bearer token on OJS 3.5 staging. Record result in `docs/ojs-api.md`. If it doesn't exist, the OJS plugin must implement full user creation via internal PHP classes.
- [ ] **Test Bearer token auth from WP server** — `curl` the OJS API with a Bearer token from the WP staging server's IP. Confirm 200 response. If 401, add `CGIPassAuth on` to `.htaccess` and retest.
- [ ] **Set up transactional email relay** — OJS is assumed to be using raw SMTP. Set up Mailgun or similar before bulk welcome email send. Check SPF/DKIM/DMARC records on the OJS mail domain.
- [ ] **Document OJS server specs** — RAM, CPU, PHP memory limit, PHP max execution time, web server type, shared or dedicated hosting.
- [ ] **Create dedicated OJS service account** — purpose-built account with minimum required role for sync operations. Generate API key. Do not use a human admin account.

---

## Phase 1: Build it

### OJS plugin (`sea-subscription-api`)

- [ ] Plugin skeleton: `plugins/generic/seaSubscriptionApi/`
- [ ] Register REST endpoints per the [endpoint spec in plan.md](docs/plan.md#ojs-endpoint-spec)
- [ ] **Idempotency**: all endpoints safe to call repeatedly with same payload
  - [ ] `find-or-create-user`: atomic lookup+insert in transaction, return existing user if email exists
  - [ ] `create/renew subscription`: upsert — check `getByUserIdForJournal()`, extend `dateEnd` if later, insert only if not found
- [ ] **Input validation**: email format (`filter_var`), integer casting on all IDs, max string lengths, HTTP 400 on invalid input. Use OJS `$request->getUserVar()` sanitisation, not raw `$_POST`.
- [ ] **IP allowlisting**: only accept requests from configured WP server IP
- [ ] **Authentication**: Bearer token, dedicated service account (not Site Admin)
- [ ] Endpoint: `GET /ping` — lightweight reachability check
- [ ] Endpoint: `GET /preflight` — compatibility check (verifies all PHP dependencies)
- [ ] Endpoint: `POST /users/find-or-create`
- [ ] Endpoint: `PUT /users/{userId}/email` — for WP email change propagation
- [ ] Endpoint: `DELETE /users/{userId}` — GDPR erasure
- [ ] Endpoint: `POST /subscriptions` — idempotent upsert
- [ ] Endpoint: `PUT /subscriptions/{id}/expire`
- [ ] Endpoint: `GET /subscriptions` — for reconciliation
- [ ] Endpoint: `POST /welcome-email` — sends "set your password" email, with dedup flag (skip if already sent)
- [ ] Configure password reset token expiry to 7 days (for bulk send)
- [ ] Custom login page message (permanent, WCAG 2.1 AA): "SEA member? First time here? Set your password"
- [ ] Paywall message for logged-in users with no subscription: "SEA member? Contact [support email]"
- [ ] OJS footer: "Your journal access is provided by your SEA membership. Manage at [WP URL]"
- [ ] No `eval()`, no raw SQL, no dynamic file includes, no shell execution
- [ ] Run PHPStan before production deploy
- [ ] Code review (second pair of eyes) before production deploy

### WP plugin (`sea-ojs-sync`)

- [ ] Plugin skeleton
- [ ] **Settings page**: OJS URL (HTTPS enforced, reject non-HTTPS), subscription type ID mapping, journal ID(s), "Test connection" button (calls `/ping` then `/preflight`)
- [ ] **API key**: read from `wp-config.php` constant `SEA_OJS_API_KEY`, not stored in database
- [ ] **Sync queue table**: custom DB table for async dispatch. Columns: `id`, `wp_user_id`, `email`, `action`, `payload`, `status`, `attempts`, `next_retry_at`, `created_at`, `completed_at`
- [ ] **Structured sync log table**: `id`, `wp_user_id`, `email`, `action` (activate/expire/create_user/email_change), `status` (success/fail), `ojs_response_code`, `ojs_response_body`, `attempt_count`, `created_at`
- [ ] **Admin log viewer**: list table with filters by status, date, email
- [ ] **WCS hooks** (primary): `status_active`, `status_expired`, `status_cancelled`, `status_on-hold` — log sync intent to queue, not inline HTTP
  - [ ] `status_active`: find-or-create user + create/renew subscription + trigger welcome email (for new users)
  - [ ] `status_expired` / `status_cancelled`: expire subscription
  - [ ] `status_on-hold`: expire subscription (decision: immediate, no grace period — document this)
- [ ] **Email change hook**: hook into WP `profile_update`, detect email change, call OJS update-user-email endpoint
- [ ] **Multiple subscriptions logic**: if member has multiple active WCS subscriptions, use latest `date_end` across all of them. If any active subscription exists, OJS access is active.
- [ ] **WP Cron queue processor**: process sync queue, retry failed items (3 attempts: 5min / 15min / 1hr), mark permanently failed after 3 attempts
- [ ] **Admin email alerts**: `wp_mail()` to admin on permanent failure; daily digest of failure count
- [ ] **Daily reconciliation**: WP Cron job — compare active WCS subscriptions vs successful sync log, retry any drift
- [ ] **Bulk sync command** (WP-CLI only):
  - [ ] Dry-run mode: report what it would do without making changes
  - [ ] Batched: process 50 users per batch, 500ms delay between API calls
  - [ ] Resume: per-user success/fail log persists across runs; skip already-synced users
  - [ ] Welcome email dedup: track "welcome email sent" flag, don't re-send on re-run
  - [ ] Welcome email batching: max 50/hour to protect email deliverability
  - [ ] Verification: after sync, compare active WCS count vs OJS subscriptions created, log any failures
  - [ ] Acceptance criteria: 100% of active WCS subscriptions result in an OJS subscription (zero failures target). Any failure individually logged with email and error reason.
- [ ] **WP member dashboard**: "Access Existential Analysis" link to OJS. Journal access status: active / not yet set up / contact us.
- [ ] **GDPR**: on WP account deletion, call OJS delete-user endpoint
- [ ] Code review before production deploy

### Pre-launch deliverables (not code)

- [x] **Draft welcome email copy** — see `launch/welcome-email.md`. Starting point for SEA to review and refine.
- [x] **Staff support runbook** — see `launch/support-runbook.md`. Starting point. 1 page:
  1. How to check WP subscription status for a member
  2. How to check OJS user account and subscription status (OJS admin UI, Users page)
  3. How to manually trigger a single-member sync (WP-CLI)
  4. How to handle email mismatch (update WP email, re-trigger sync)
  5. How to read the WP sync error log
- [x] **Member FAQ** — see `launch/member-faq.md`. Starting point. Covers:
  - "I already have an OJS account with a different email"
  - "I didn't receive the setup email"
  - "I'm paying but can't access the journal"
  - "How do I update my email address?"
- [ ] **OJS upgrade rollback runbook** (if not done in Phase 0.5)
- [ ] **Plugin deployment runbook** — how to deploy/rollback each plugin

### Launch communication

- [ ] **Define launch sequence timing**: (1) complete bulk sync, verify counts → (2) send welcome emails → (3) wait for email delivery → (4) send member announcement
- [ ] **Member announcement** — via SEA's normal newsletter/email channel. "Your membership now includes access to Existential Analysis. Check your email for instructions on setting up your access."
- [ ] **Pre-launch communication** (optional) — heads up that the email is coming, so members don't mistake it for phishing

### End-to-end smoke test checklist

- [ ] Create test WCS subscription → WP hook fires → OJS user created → OJS subscription active
- [ ] Visit paywalled article as synced user → access granted
- [ ] Expire WCS subscription → OJS subscription expired → paywall denies access
- [ ] Visit paywalled article as non-member → purchase options displayed with correct prices
- [ ] Complete test non-member purchase → access granted
- [ ] Change WP email → OJS email updated
- [ ] Trigger welcome email → email received → set password link works
- [ ] Expired token → test error page → recovery path works
- [ ] "Test connection" button → success/failure correctly displayed
- [ ] OJS down during sync → event queued → OJS back up → event retried → subscription created
- [ ] Bulk sync dry-run → correct output → full run → verify counts match

---

## Phase 2: Robustness (after Phase 1 ships)

- [ ] Admin dashboard: per-member sync status with visual indicator
- [ ] Smarter nightly reconciliation: differential (modified in last 25hr first, then count comparison, full record-by-record only if counts differ)
- [ ] Rate limiting on OJS plugin endpoints (application-layer, beyond IP allowlist)
- [ ] 30-day follow-up email to members who haven't set their OJS password
- [ ] OJS `on-hold` grace period (if SEA decides they want one — currently immediate expiry)
- [ ] API key rotation support: OJS plugin accepts two keys simultaneously during rotation window
- [ ] Track OJS subscription ID in WP usermeta for more precise expire/update calls

## Phase 3: UX (nice to have)

- [ ] Onboarding email for new members who join after launch (beyond the welcome email)
- [ ] OJS notification on access suspension/restoration (WP plugin sends email on on-hold/reactivation)
- [ ] Password reset flow documentation for members
- [ ] OJS accessibility audit (WCAG 2.1 AA on core flows)

---

## Open questions

1. Does the OJS user creation API (POST /users) work on 3.5? Must verify on staging — Phase 0.75.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| OJS 3.5 upgrade fails or causes data corruption | Medium | Critical | Staging first (done — 3.5.0.3 running), rollback runbook, go/no-go threshold |
| User creation API doesn't exist | Medium | Medium | OJS plugin handles this too (Phase 0.75 verifies) |
| Sync failures silently drop members | Medium | High | Async queue with retries, daily reconciliation, admin alerts |
| Members confused by two logins | High | Medium | Welcome email, permanent login prompt, cross-links, support runbook |
| OJS upgrade breaks custom plugin | Medium | High | `/preflight` endpoint verifies all PHP dependencies. Run after any OJS upgrade. |
| Members don't set OJS password | High | Medium | Welcome email + permanent login prompt + 30-day follow-up (Phase 2) |
| Email change breaks sync | Medium | High | WP email change hook propagates to OJS |
| API key compromised | Low | Critical | `wp-config.php` constant, dedicated service account, IP allowlist |
| Bulk welcome emails spam-filtered | Medium | Medium | Transactional email relay, SPF/DKIM/DMARC, batch 50/hour |
| Apache strips auth headers silently | Medium | High | Phase 0.75 verification from WP server IP |
| GDPR erasure request | Low | High | Delete-user endpoint on OJS plugin, triggered on WP account deletion |
| Manual member roles missed by sync | Medium | High | Bulk sync and reconciliation check WP roles directly, not just WCS status |
