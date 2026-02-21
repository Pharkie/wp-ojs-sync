# Future: Membership Platform Replacement

Last updated: 2026-02-21.

Not in scope for the OJS sync project, but the current WP membership stack is fragile and expensive. As we work through the sync integration, document what a proper replacement would need to do.

## Why replace it

The current stack is six plugins wired together (WooCommerce + WC Subscriptions + WC Memberships + Ultimate Member + UM-WooCommerce + UM-Notifications). Problems:

- **Complexity** — six plugins, three vendors, each with their own update cycle, hooks, database tables, and breaking changes
- **Cost** — WC Subscriptions alone is ~£200/year. WC Memberships, UM-WooCommerce, and UM-Notifications are additional paid licences.
- **Fragility** — role assignment chain spans three plugins (WCS → WCM → UM). A bug or breaking update in any one of them can silently break membership access. We hit this directly during the OJS sync build: UM custom roles aren't registered during early WP bootstrap, so `wp user import-csv` can't assign them. Production role assignment depends on the full plugin chain loading in the right order.
- **Indirection** — simple questions ("is this person a member?") require querying across multiple plugin tables and role systems. Our `is_active_member()` function has to check WCS subscription status, exclude the subscription being cancelled, and handle manual roles separately.
- **No real API** — WordPress has no native membership API. Integrating with external systems (like OJS) means writing custom plugins that hook into PHP internals, managing background job queues, writing direct SQL against plugin tables, and deploying code to a virtual server. Every integration is a bespoke engineering project.
- **Not infrastructure as code** — we've spent days wrapping WordPress in Bedrock, Composer, Docker, and scripted setup to make it reproducible. It's still fragile. A modern platform would have this out of the box.
- **WordPress limitations** — WP was not designed as a membership/CRM platform. Everything is bolted on. The underlying architecture (serialized PHP in `wp_usermeta`, no proper ORM, plugin load-order dependencies) creates problems that don't exist on modern platforms.

The main requirement for a replacement is **modern technical architecture**: a proper REST API, webhooks, structured data, so that integrations (like the OJS journal sync) can be built and maintained without hitting a wall of PHP internals, SQL workarounds, and six-plugin dependency chains.

## What the membership system actually does

Core requirements (what SEA members and admins actually need):

- Member registration with profile fields
- Recurring subscription billing (£35–60/year depending on tier)
- Automatic access grant/revoke based on payment status
- Member directory (with opt-in/opt-out for listing)
- Member profiles (public-facing)
- Admin ability to manually grant access (Exco, life members)
- Email communications to members
- Integration with journal access (OJS or whatever replaces it)
- Events (SEA runs workshops and conferences)

Tier structure (current):

| Tier | Price | Variants |
|------|-------|----------|
| UK member | £50/yr | with/without directory listing |
| International member | £60/yr | with/without directory listing |
| Student member | £35/yr | with/without directory listing |
| Manual (Exco/life) | Free | admin-assigned |

## Requirements discovered during OJS sync build

Things that any replacement would need to handle, learned from building the push-sync integration:

- **API access is non-negotiable.** The OJS sync needs to read membership status programmatically. Any platform without an API would require fragile CSV-export workarounds instead of real-time sync.
- **Webhook or event support.** The sync is event-driven — fires on subscription status changes (active, expired, cancelled, on-hold). A replacement must emit events or webhooks when membership status changes.
- **Manual/honorary members.** Some members (Exco, life members) have access without a subscription. The system needs admin-assignable membership that bypasses the payment check.
- **Multi-subscription awareness.** Members can have multiple subscriptions (e.g. lapsed and renewed). "Is this person a member?" must check if *any* subscription is active, not just the most recent one.
- **Email as matching key.** The OJS sync uses email to match users across systems. A replacement must have stable, unique email addresses as user identifiers.
- **GDPR erasure.** When a member is deleted, their data must be cleaned up on OJS too. A replacement must support pre-deletion webhooks or events.
- **Bulk operations.** Initial sync pushes ~700 members to OJS at once. The platform needs to support bulk reads via API without punitive rate limits.
- **UK payment gateway.** Stripe (or any mainstream processor that handles GBP recurring payments).

## Platform comparison (~500 members)

Evaluated 2026-02-21. Pricing verified from official websites.

### Shortlisted

| Platform | Type | Cost (~500 members) | API | Verdict |
|----------|------|---------------------|-----|---------|
| **WildApricot** | SaaS | ~$125/mo (~£1,200/yr) | Yes (REST, Swagger docs) | Strongest SaaS. All features included. GBP via Stripe. |
| **CiviCRM** | Open source (WP/Drupal) | Free + hosting (~£300-900/yr) | Yes (REST APIv4, mature) | Most capable. Runs on WP. Widely used by UK societies. Complex to set up. |
| **Beacon CRM** | UK SaaS | ~£78/mo (~£936/yr excl. VAT) | Yes (REST) | UK-native, REST API. Closer to WildApricot price than expected. More charity CRM than AMS — verify depth. |
| **Paid Memberships Pro** | WP plugin | Free–£240/yr | Yes (all tiers, basic) | Best value if staying on WP. Open source. |

### Detailed notes

#### WildApricot (~£1,200/yr)

All-in-one SaaS: members, payments, events, email, website, API. The best-documented API in this comparison (Swagger/OpenAPI, GitHub code samples). Tiers are by contact count only — all features included at every tier.

- **Pro:** Mature REST API, all features included, large user base. Supports GBP billing via Stripe. No server to manage.
- **Con:** Platform subscription billed in USD (~$125/mo for 500 contacts, 2yr prepay). Export is CSV-only (no full backup). North American company.
- **OJS integration:** Rebuild sync against WildApricot API (webhooks + REST). Same push-sync pattern, different source.

#### CiviCRM (free + hosting)

Open-source CRM built specifically for nonprofits, NGOs, and membership organisations. Integrates with WordPress, Drupal, and Joomla. Widely used by UK charities and learned societies. Mature REST API (APIv4).

- **Pro:** Free software. Comprehensive membership management (CiviMember). REST API is mature and well-documented. Supports Stripe and GoCardless. Runs on WordPress (which SEA already has). Large community, UK specialists available. No per-member fees.
- **Con:** Significant setup complexity — needs a technically capable person or CiviCRM specialist. Still runs on WordPress (same hosting/maintenance burden). Learning curve for admins. Can feel enterprise-heavy for a 500-member society.
- **OJS integration:** Good. REST APIv4 supports reading membership status. Could use CiviCRM's scheduled jobs or hooks to trigger OJS sync.
- **Note:** CiviCRM Spark (hosted) is ~$10-15/mo but capped at 5,000 contacts and limited extensions. Managed hosting from specialists (e.g. Skvare, CiviDesk) is £20-80/mo.

#### Beacon CRM (~£936/yr excl. VAT)

UK-built charity CRM with membership management. Designed for UK charities and nonprofits.

- **Pricing:** Starter plan £59.50/mo + Memberships add-on £11/mo + Events & ticketing £7.50/mo = **£78/mo (£936/yr)** on annual billing (10% discount). Excludes VAT. Up to 1,000 contacts. 25 custom fields included.
- **Pro:** UK-native, GBP billing. REST API. Stripe integration. Zero transaction surcharges on payments. Built for UK charities.
- **Con:** More expensive than initial research suggested — closer to WildApricot than expected. Leans more charity/fundraising than association management. Verify whether membership features are deep enough (tiered levels, auto-renewal by tier, member directory). Memberships and Events are paid add-ons, not included in base price.
- **OJS integration:** Possible via REST API. Would need investigation.

#### Paid Memberships Pro (free–£240/yr)

Open-source WordPress membership plugin. REST API on all tiers including free. Replaces WCS + WCM + UM in one plugin.

- **Pro:** Free tier with Stripe + API (unique). Open-source core. Active community.
- **Con:** API is basic (7 endpoints). Directory/profiles require Plus tier (£240+/yr). Email via third-party. Still WordPress — same underlying architectural problems.
- **OJS integration:** Minimal change from current sync. Same WP hooks, different membership check.

### Also evaluated (not shortlisted)

| Platform | Why excluded |
|----------|-------------|
| **membermojo** (~£95/yr) | No API. Cheapest option but can't integrate with OJS. |
| **White Fuse** (~£1,000/yr) | No API. Good UK all-in-one otherwise. |
| **Join It** (~£950/yr) | Expensive. 2% transaction surcharge on top of Stripe fees. API locked to $99/mo tier. |
| **MemberPress** (£280–500/yr) | API locked to Scale tier (£500+/yr, doubles after year 1). Not worth the premium over PMPro. |
| **Salesforce Nonprofit** (free + £10-30k setup) | Massive overkill. Requires dedicated admin expertise SEA doesn't have. |
| **Novi AMS** (~$829/mo) | Far too expensive for a 500-member society. |
| **MemberClicks** (~$375/mo) | Expensive, US-focused. Designed for larger associations. |
| **GrowthZone** (~$250-325/mo) | Expensive, US chamber-of-commerce focused. |
| **sheepCRM** (~£399/mo) | UK-native but too expensive for 500 members. |
| **Outseta** (~$37-47/mo) | Cheap with API, but no member directory. 2% transaction fee. SaaS/startup-oriented, not association-focused. |
| **Tendenci** (~$249/mo hosted) | Open-source AMS but immature API, small community, expensive hosting. |
| **Baserow** (free) | Database, not a membership platform. Would mean building everything custom — unsustainable. If the developer who built it moves on, SEA is left with a bespoke system nobody else can maintain. This needs to last 10-15 years. |

## What WildApricot actually fixes

The point of moving isn't to get a shinier UI. It's to get off a platform that fights you every time you try to extend it. Here's what changes concretely:

### Architecture

| | WordPress (current) | WildApricot |
|---|---|---|
| **"Is this person a member?"** | Query WCS subscription status across multiple DB tables, check role assignment chain, handle manual roles separately, write custom PHP | One API call: `GET /accounts/{id}/contacts/{id}` — returns membership level and status |
| **Integrating with external systems** | Write a custom WP plugin, hook into PHP internals, manage Action Scheduler background jobs, deploy to a server, pray the six-plugin chain doesn't break | Call the REST API or receive a webhook. Standard HTTP. Any language. |
| **Membership status changes** | Hook into `woocommerce_subscription_status_*`, which only fires if WCS is active, loaded in the right order, and not broken by an update | Webhook fires on membership status change. Documented. Reliable. |
| **Querying members in bulk** | `wp user list` + WP_User_Query + manual joins to subscription tables. Or raw SQL. | `GET /accounts/{id}/contacts?$filter=...` — standard OData filtering, pagination, all fields |
| **Dev environment** | Bedrock + Composer + Docker + custom Dockerfiles + scripted setup + SQL workarounds for role seeding. Days of work to make reproducible. | Sign up for a sandbox account. |
| **Deploying changes** | SSH to a server, manage PHP versions, Apache config, database backups, plugin updates that might break each other | Nothing to deploy. It's SaaS. |
| **Data model** | Serialized PHP arrays in `wp_usermeta`. No ORM. No schema. Six plugins each with their own tables and conventions. | Structured JSON via API. Documented schema. |

### What you stop doing

- **Stop managing WordPress infrastructure.** No more servers, PHP versions, Apache config, SSL certs, plugin updates, database backups, security patches.
- **Stop writing custom plugins for basic integrations.** The OJS sync becomes a lightweight service that reads the WildApricot API — not a WordPress plugin wired into PHP hooks and Action Scheduler.
- **Stop debugging plugin interactions.** No more "WCS fires before WCM assigns the role" or "UM roles aren't registered during early bootstrap." One platform, one data model.
- **Stop paying for six plugin licences.** WCS (~£200/yr) + WCM + UM-WooCommerce + UM-Notifications. All replaced by one subscription.
- **Stop maintaining Bedrock/Composer/Docker.** The infrastructure-as-code wrapper we built is impressive but shouldn't be necessary. A modern platform doesn't need wrapping.

### What you gain

- **A real API.** Swagger-documented REST endpoints. Standard OAuth2 authentication. Any developer can integrate with it, in any language, without learning WordPress internals.
- **Webhooks.** Membership changes trigger HTTP callbacks. The OJS sync becomes a small standalone service (or cloud function) rather than a WordPress plugin.
- **One source of truth.** Members, payments, events, email — all in one system with one data model. No more querying across plugin tables.
- **Portability.** The OJS sync would be a standalone service calling a REST API — not tied to a specific platform. If you later move from WildApricot to something else, the sync adapts by changing API calls, not rewriting a WordPress plugin.
- **Sustainability.** Any developer can pick this up. The API is documented, the platform is maintained by a company, the data is accessible. No single person's WordPress plugin knowledge required.

### What you lose

- **Full control over the codebase.** WordPress is open-source PHP — you can hack anything. WildApricot is a black box. If they don't support something, you can't fix it yourself.
- **Custom functionality.** If SEA needs something WildApricot doesn't offer, you're limited to what the API exposes. WordPress (for all its faults) lets you build anything.
- **Data sovereignty.** Your member data lives on WildApricot's servers (US/Canada). With WordPress, it lives on your own server.
- **The current WP site.** SEA's existing website content, pages, and blog would need to move to WildApricot's website builder (limited) or remain on a separate WordPress install (without the membership plugins).

## Recommendation

**Replace WordPress.** The current stack is not viable long-term. We've spent days making it "infrastructure as code" — Bedrock, Composer, Docker, scripted setup — and it's still fragile. Six plugins from three vendors, paid licences, role assignment chains that break during bootstrap, no native API, test data that can't be seeded without SQL workarounds. This is technical debt, not a platform.

The OJS sync is being built against the current stack because it exists today, but the push-sync pattern (event → API call → OJS) would work the same against any platform with webhooks or an API. The sync plugin is the easy part. The membership platform is the hard part.

### Top candidates

1. **WildApricot** — leave WordPress entirely. ~£1,200/yr. All-in-one SaaS with mature REST API. The OJS sync becomes a lightweight external service instead of a WordPress plugin. No servers, no plugin chains, no PHP internals. The strongest option if SEA wants a clean break and modern architecture.

2. **CiviCRM** — stay on WordPress but replace the plugin chain with a proper CRM. Free software + hosting costs. Mature REST API, widely used by UK societies. The most capable option feature-wise, but needs specialist setup and still runs on WordPress (same hosting burden). Best if SEA has access to CiviCRM expertise or is willing to pay a specialist for initial setup.

3. **Paid Memberships Pro** — stay on WordPress, simplify the plugin stack. Free–£240/yr. Replaces 6 plugins with 1. Has an API (basic). Lowest migration effort, but doesn't solve the fundamental WordPress problems (server management, fragile infrastructure, no real API).

### What to do next

This is a decision for SEA, not a technical call. The questions are:

- **Does SEA want to stop managing servers and WordPress?** → WildApricot. Higher cost, but the infrastructure and maintenance burden goes to zero.
- **Does SEA want maximum capability and is willing to invest in setup?** → CiviCRM. Most powerful option, but needs specialist knowledge.
- **Does SEA want minimum disruption right now?** → Paid Memberships Pro. Cheapest and easiest migration, but doesn't fix the underlying architecture.
- **What's the budget?** → PMPro is free. CiviCRM is free + hosting. WildApricot is ~£1,200/yr. The current stack is ~£400/yr in licences plus hosting plus developer time that dwarfs all of them.

The OJS sync work is not wasted regardless of which path SEA chooses — the push-sync pattern ports to any platform with an API.
