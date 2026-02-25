# WildApricot (~£1,200/yr)

All-in-one SaaS: members, payments, events, email, website, API. Swagger-documented REST API. Tiers are by contact count only — all features included at every tier. Founded 2006 in Canada.

## Pricing

Platform subscription billed in USD (~$125/mo for 500 contacts, 2yr prepay). No single-operation full backup (must export each data type separately; supports CSV, XLS, and XML). North American company — data hosted in US/Canada (AWS).

## Pro/Con

**Pro:**

- All features included, large user base (15,000-32,000 organisations)
- Supports GBP billing via Stripe
- No server to manage
- Lowest setup effort
- REST API with webhooks covers the OJS integration use case

**Con:**

- No single-operation full backup (must export each data type separately; supports CSV, XLS, and XML)
- North American company — data hosted in US/Canada (AWS)
- API rate limits are tight (40 requests/min for contact lists)
- No SLA or uptime guarantee

## OJS Integration

Rebuild sync against WildApricot API (webhooks + REST). Same push-sync pattern, different source.

## Vendor Risk

**Private equity ownership and declining support.**

WildApricot was acquired by Personify in 2017 (backed by private equity firm Rubicon), then Personify was sold to another private equity firm (Pamlico Capital) in 2018. The original founder (Dmitry Buterin) left after the acquisition. Two private equity flips in two years.

- **Support quality has declined significantly post-acquisition.** This is the most consistent complaint across review sites. Trustpilot: 1.6/5 (154 reviews). Capterra: 4.4/5 (554 reviews). The gap is stark — Trustpilot captures more complaint-driven reviews, but 1.6/5 with 154 reviews is not noise. Users describe email/chat-only support with weeks-long response times.
- **Aggressive price increases.** ~25% increases every two years with 60 days notice. At this rate, prices roughly double every 6 years. Users report "zero product improvement despite multiple large price increases."
- **Team size is uncertain.** Reports range from 17 to 200 employees. Glassdoor reviews describe layoffs and loss of engineering staff post-acquisition. One review described "only 8-9 people in an office space designed for 150+."
- **No contractual data portability after termination.** Data is exportable while your account is active, but the Terms of Use contain no provisions for data export after account termination.
- **Another acquisition is likely.** Pamlico has held Personify since 2018 (7+ years, approaching typical private equity hold period). Another sale could mean price hikes, product sunset, or absorption into a larger platform.

## Bottom Line

WildApricot works well as a turnkey membership platform today. But the private equity ownership model is optimised for revenue extraction, not product investment. The risks are corporate/commercial (declining support, price instability, potential acquisition, no source code access) rather than CiviCRM's community/sustainability risks (small team, key-person dependency, financial stress). Neither is risk-free; they fail in different ways.
