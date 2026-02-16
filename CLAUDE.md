# CLAUDE.md

## Project

WordPress ↔ OJS integration for the Society for Existential Analysis (SEA). WP manages memberships; OJS hosts the journal *Existential Analysis* behind a paywall. Goal: members get access, non-members can still buy content.

## Live sites

- **WP:** https://community.existentialanalysis.org.uk/
- **OJS:** https://journal.existentialanalysis.org.uk/index.php/t1/index

## Key docs (read these first)

- `docs/architecture.md` — decision trail: what was tried, what was eliminated, and why
- `docs/ojs-api.md` — OJS REST API capabilities, DB schema, PHP internals
- `docs/phase0-findings.md` — raw research from API audit
- `docs/phase0-sso-plugin-audit.md` — source code audit of Subscription SSO plugin
- `TODO.md` — task list with blocking questions and phased implementation plan

## Architecture decision

**Custom OJS plugin + WP plugin.** OJS has subscription management classes internally but no HTTP API for them. We build a small OJS plugin to expose subscription CRUD as REST endpoints, and a WP plugin to call them on membership changes. See `docs/architecture.md` for the full decision trail.

This aligns with the previous developer's "Plan C" — the main addition is that we need a small OJS plugin because the REST API doesn't cover subscriptions natively.

## Hard constraints

- **WP is source of truth** for membership. OJS is downstream.
- **OJS paywall must keep working** for non-member purchases (£3 article, £25 issue, £18 back issue).
- **No OJS core modifications.** Plugins only.
- **Ship fast.** Project is over budget. Prefer boring, reliable solutions.

## Eliminated approaches (don't revisit)

- **OIDC/OpenID SSO** — only solves login not access; OJS plugin has unresolved bugs, no production-ready 3.5 release, breaks multi-journal setups. Previous developer confirmed independently.
- **Subscription SSO plugin** — source code audit confirmed it hijacks OJS purchase flow. Non-members can't buy content while it's active. See `docs/phase0-sso-plugin-audit.md`.
- **OJS REST API sync (native)** — subscription endpoints don't exist in any OJS version.

## Gotchas

- **OJS has NO subscription REST API.** The endpoints don't exist. That's why we need a custom OJS plugin. See `docs/ojs-api.md`.
- **User creation API is unconfirmed.** Swagger spec shows read-only user endpoints. Verify against actual OJS version before relying on it.
- **Apache + PHP-FPM strips Authorization headers.** Need `CGIPassAuth on` in `.htaccess` or use `?apiToken=` query param fallback.
- **OJS 3.4 vs 3.5 matters a lot.** 3.5 has clean plugin API extensibility (Laravel routing). 3.4 doesn't. If stuck on 3.4, fall back to direct DB writes.

## Code conventions

- WordPress plugin standards (PHP)
- Prefix everything `sea_ojs_`
- Use WP HTTP API (`wp_remote_post` etc.) — not raw cURL
- Use WP Cron for scheduled tasks, not system cron
- Log all sync operations — failures must be visible in WP admin
- Settings page for OJS URL, API key, subscription type mapping

## Don't

- Modify OJS source code
- Sync passwords between systems
- Build message queues, webhook servers, or microservices
- Add features beyond the core sync requirement
- Assume any OJS API endpoint exists without checking `docs/ojs-api.md`
- Revisit OIDC, Subscription SSO, or native REST API sync — all eliminated with documented reasons
