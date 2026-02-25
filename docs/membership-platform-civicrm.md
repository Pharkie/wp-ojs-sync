# CiviCRM (~£115/yr self-hosted)

Open-source CRM (AGPL). Since v6.0 (March 2025) can run standalone — no WordPress/Drupal required. CiviMember for memberships, CiviEvent for events, CiviMail for email. Used by Amnesty International, EFF, Wikimedia Foundation, and over 9,000 organisations worldwide. Ranked #1 for cost-effectiveness in the 2025 UK Charity CRM Survey.

## Pricing

Software is free. Hosting ~£115/yr (DigitalOcean droplet, $12/mo — 2GB RAM for PHP + MySQL on one server). CiviCRM Spark (managed cloud) is $15-50/mo but too limited for SEA — can't install custom extensions needed for OJS integration and CPD tracking.

## Pro/Con

**Pro:**

- Best API in this comparison (APIv4 — full CRUD on all entities, API Explorer built in)
- Stripe + GoCardless for GBP recurring payments
- CiviMember handles tiered memberships, auto-renewal, manual/honorary members, status lifecycle
- CiviEvent is mature for workshops/conferences
- No vendor lock-in. Data ownership
- Standalone mode eliminates WordPress entirely
- Strong UK ecosystem
- UK tech partners available if needed (e.g. Circle Interactive, Third Sector Design)

**Con:**

- Not turnkey — requires implementation and ongoing technical maintenance
- No native outbound webhooks (membership lifecycle hooks exist for building custom extensions, and CiviRules can automate actions on triggers)
- Member directory requires configuration (SearchKit + FormBuilder) rather than being built-in
- Admin interface is functional rather than polished
- CPD/accreditation tracking has no production-ready extension — would need custom build using CiviCase or custom fields

## OJS Integration

Build a custom CiviCRM extension using `hook_civicrm_post` on Membership entity changes to push updates to OJS via HTTP. Architecturally identical to the current WP push-sync — replacing the WP side with CiviCRM. API and hooks to support this exist; integration code does not.

## Architecture

CiviCRM is still PHP/MySQL — but the problem with the current WP stack is WordPress's architecture on top of PHP/MySQL, not PHP/MySQL itself. CiviCRM has a properly normalised relational schema (dedicated tables for contacts, memberships, contributions — not serialised arrays in `wp_usermeta`), a Symfony DI container, a well-designed APIv4 with full CRUD, and a real event system. These are genuine architectural improvements over WordPress.

However:

- **Key-person dependency is high.** Two developers (Eileen McNaughton and Coleman Watts) account for 43% of all 72,704 commits and dominate current weekly activity. Core team is 7 people. Only 19 contributors active in the last month. If key contributors stopped, the project would be in trouble.
- **Financial health is weak.** Charitable income down ~30% YoY. Running a budget deficit. Health score 60/100. Subscription income is growing but not enough to offset the decline.
- **Mid-modernisation codebase.** Legacy `CRM_*` classes (no namespaces, 2000s-era PHP) coexist with modern `\Civi\*` code (namespaces, PSR-0, Symfony components). The transition has been going on for years and is not complete. You will encounter both styles.
- **Upgrades can break things.** Monthly releases with forward-only migrations (no rollback). Users report "after every update there are things that break" (Capterra: 3.9/5 stars). Better than WordPress's complete lack of migrations, but not modern.
- **Tiny community.** 718 GitHub stars, ~41 active contributors per year. If you hit a bug, the pool of people who can help is vastly smaller than WordPress's ecosystem. Documentation is adequate but uneven.

## Bottom Line

CiviCRM is architecturally better than WordPress in the areas that matter (data model, API, DI, events). But it's a 20-year-old application maintained by a small, financially stressed team. You'd be trading WordPress's problems (terrible data model, six-plugin fragility, no API) for CiviCRM's problems (small community, key-person dependency risk, mid-modernisation inconsistency, financial fragility). The architecture is better; the ecosystem is worse.
