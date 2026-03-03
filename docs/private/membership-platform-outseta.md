# Outseta (~£640/yr + 1% surcharge)

All-in-one SaaS: billing, CRM, email marketing, authentication, help desk. All features included at every tier — no add-ons. Tiers are by contact count only. Founded 2016 in San Diego, USA. Bootstrapped (no VC, no private equity). ~6,000 customers. Team of 7 with equity stakes. Profitable.

## Pricing

Start-up plan $87/mo ($67/mo on annual billing) for up to 5,000 contacts. All features included. Billed in USD.

**1% transaction surcharge** on top of Stripe's standard payment processing fees (1.5% + 20p for UK cards). The Founder tier ($37/mo, 1,000 contacts) is cheaper but has a 2% surcharge — and SEA would likely exceed 1,000 contacts once lapsed members, prospects, and admin accounts are counted. At $67/mo annual, that's ~$804/yr (~£640/yr).

The 1% surcharge on ~£32,500/yr of membership revenue (~650 members x ~£50 avg) adds ~£325/yr, making the **effective cost ~£965/yr** — comparable to Beacon, cheaper than WildApricot.

### Stripe Billing nuance

Outseta handles subscription/recurring logic itself and only uses Stripe Payments to process each charge — so you don't pay Stripe Billing's additional 0.7% fee. Outseta claims most other membership platforms create Stripe Subscription objects under the hood, triggering that hidden 0.7%. If true, the real gap between Outseta's 1% surcharge and a platform with no surcharge but Stripe Billing is only ~0.3%. However, we haven't confirmed whether WildApricot, Beacon, or other shortlisted platforms actually use Stripe Billing — so take Outseta's comparison at face value but verify before relying on it.

## Pro/Con

**Pro:**

- Genuinely all-in-one at a fraction of WildApricot's price
- REST API with webhooks (POST callbacks on membership events, SHA256 signature verification, 20 retries at 20-minute intervals on failure)
- GBP billing supported (any Stripe-supported currency)
- Email marketing with drip sequences and CRM segmentation
- Self-service member portal (profile management, subscription management, payment updates)
- Team/group memberships supported
- Bootstrapped and profitable — no private equity risk, no aggressive price increases
- Founders have a track record (co-founder Dimitris Georgakopoulos previously co-founded Buildium, acquired by RealPage for $580M)

**Con:**

- **No member directory** — this is a real gap for SEA, which needs a public opt-in/opt-out directory. Outseta provides self-service profiles and a CRM, but no public-facing directory page. Building one would mean querying the API externally and rendering it yourself.
- **No event management** — SEA runs workshops and conferences; would need a separate tool (e.g. Eventbrite, Tito).
- **1% transaction surcharge** on the Start-up tier (see Stripe Billing nuance above for context on the real cost difference).
- **Honorary/manual members require a workaround** — create a $0 plan or apply a 100% discount code; not a first-class feature.
- **API documentation has gaps** — rate limits are not documented, webhook event types are not fully enumerated, Postman collection is the best reference.
- **Data export is limited** — CSV export from CRM, API-based extraction possible, but no "export everything" button.
- **Small team** (7 people) — same bus-factor concern as CiviCRM.
- **SaaS-startup roots** — originally built for SaaS companies, not associations, though they now actively market to associations and have 24+ association/club customers (BHRLA, NIFA, IADS, Mezcla Media Collective, UK Soul Choirs, etc.).
- **US-hosted** — data sovereignty same concern as WildApricot.
- **No Trustpilot presence** — too small for independent review volume.

## OJS Integration

Rebuild sync against Outseta API. Webhooks fire on subscription events → push to OJS. REST API for bulk member reads. Same push-sync pattern as the current WP approach. The API is adequate for this; the real question is whether it handles edge cases (subscription status transitions, multiple subscriptions per person) cleanly. Outseta uses one subscription per account, which is cleaner than WCS's multiple-subscription model.

## Vendor Risk

**Small but stable.**

Outseta is the anti-WildApricot in terms of ownership structure. Bootstrapped for 9 years, no external investors, all 7 team members hold equity. Revenue growing 55% YoY. The founders have significant SaaS experience (Buildium exit). There's no PE firm optimising for revenue extraction.

However:

- **Team of 7.** If Outseta were acquired, wound down, or lost key people, there's no open-source code to fork and no large community to fall back on. You'd need to migrate away, same as any SaaS.
- **Young product.** Founded 2016, ~6,000 customers. WildApricot has 15,000-32,000. CiviCRM has 9,000+. Outseta is smaller and less proven at scale.
- **Low review volume.** See reviews section below. The positive sentiment is real, but the sample size is small. Hard to know how it performs under stress (platform outages, billing disputes, complex migrations).

## Reviews

**Positive but thin.**

| Platform | Rating | Reviews | Notes |
|----------|--------|---------|-------|
| Capterra | 4.3/5 | 7 | Ease of Use 4.3, Customer Service 4.3, Features 4.4, Value 4.1. 86% would recommend. |
| Product Hunt | 5.0/5 | 6 | Endorsed by Justin Welsh, Corey Haines, Tom Osman. |
| G2 | — | ~3 | Too few for an aggregate score. |
| GetApp | — | ~7 | Same reviews as Capterra (shared platform). |
| Trustpilot | — | 0 | No presence. |

**What reviewers consistently praise:**

- All-in-one value — "don't have to worry about API limits or data syncing errors because customer data stays in one platform." Multiple reviewers cite replacing 4-5 separate tools.
- Support responsiveness — team described as "absolutely brilliant," responds to bug reports quickly, has added features customers requested.
- Ease of setup — minimal learning curve, guided onboarding, tutorial videos. Webflow integration is a particular strength.
- Group/team memberships — uncommon feature that distinguishes it from competitors like Memberstack.

**What reviewers consistently criticise:**

- Stripe-only payments — dealbreaker for regions where Stripe isn't available (not an issue for SEA — Stripe works in the UK).
- Limited design customisation — embedded forms and widgets have restricted styling. Only Google sign-in for social auth (Memberstack offers six options).
- Email marketing is basic — adequate for newsletters and drip sequences, but not as capable as Mailchimp or ActiveCampaign for complex campaigns.
- No course creation — relevant for education/creator businesses, not for SEA.
- Analytics could be deeper — dashboard and reporting described as functional but limited.
- CRM features described as "incomplete" by one reviewer — adequate for small organisations, may not suit enterprise needs.

**What's missing from the review record:** No reviews from association or nonprofit users specifically. All visible reviews are from SaaS founders, creators, or small startup operators. This doesn't mean it doesn't work for associations — Outseta lists 24+ association customers — but there's no independent validation from that use case on review platforms.

## Bottom Line

Outseta is a compelling WildApricot alternative — same all-in-one model, much cheaper, better ownership structure. The API and webhooks cover the OJS integration use case. The two real gaps are **no member directory** (SEA needs this) and **no event management** (SEA needs this). If those can be solved externally (custom directory page via API, separate events tool), Outseta deserves serious consideration. The 1% transaction surcharge is a cost to factor in but doesn't change the overall value proposition. The biggest risk is the small team and young product — you're betting on a 7-person company being around in 10 years.
