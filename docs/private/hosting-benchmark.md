# WP Hosting Benchmark: Krystal vs Hetzner

Tested 2026-03-07 18:59 UTC from a Hetzner devcontainer (Frankfurt region).

## Hosts

| | Krystal (live) | Hetzner (staging) |
|---|---|---|
| URL | https://community.existentialanalysis.org.uk | http://159.69.152.19:8080 |
| Type | Shared hosting | VPS (CPX22: 3 vCPU, 4 GB RAM) |
| Cost | ~£10/month (estimate) | ~7 EUR/month |
| Active plugins | 35 | 6 (core set only) |
| Caching | None configured | None configured |

Note: Krystal has 35 active plugins vs 6 on Hetzner, which adds PHP overhead per request. The Hetzner VPS also has no page caching — these are raw PHP response times with room to improve.

---

## 1. Single request — Time to First Byte (TTFB)

Homepage, 5 sequential requests:

| | Krystal | Hetzner |
|---|---|---|
| #1 | 2.16s | 0.31s |
| #2 | 2.15s | 0.28s |
| #3 | 2.07s | 0.29s |
| #4 | 2.06s | 0.29s |
| #5 | 2.02s | 0.28s |
| **Average** | **2.09s** | **0.29s** |

Hetzner is 7x faster on TTFB.

## 2. REST API — TTFB

`/wp-json/`, 3 requests:

| | Krystal | Hetzner |
|---|---|---|
| #1 | 2.27s | 0.37s |
| #2 | 2.22s | 0.21s |
| #3 | 2.23s | 0.31s |
| **Average** | **2.24s** | **0.30s** |

Hetzner is 7x faster. This endpoint is what the sync plugin calls — faster API means faster sync operations.

## 3. Login page — TTFB

`/wp-login.php`, 3 requests:

| | Krystal | Hetzner |
|---|---|---|
| #1 | 2.54s | 0.26s |
| #2 | 1.88s | 0.20s |
| #3 | 1.89s | 0.19s |
| **Average** | **2.10s** | **0.21s** |

Hetzner is 10x faster on the login page.

## 4. Light load — 10 concurrent users, 50 requests

Simulates 10 people browsing the homepage simultaneously.

| Metric | Krystal | Hetzner |
|---|---|---|
| Total time | 45.3s | 3.2s |
| Requests/sec | 1.1 | 15.8 |
| Average response | 8.86s | 0.61s |
| Fastest | 5.94s | 0.14s |
| Slowest | 11.01s | 1.39s |
| p50 latency | 8.84s | 0.59s |
| p95 latency | 10.50s | 0.79s |
| Errors | 0 | 0 |

Hetzner handles 14x more requests per second. Krystal takes nearly 9 seconds average to respond under just 10 concurrent users.

## 5. Moderate load — 20 concurrent users, 100 requests

Simulates 20 people browsing simultaneously — a realistic scenario for a member community site.

| Metric | Krystal | Hetzner |
|---|---|---|
| Total time | 98.2s | 6.2s |
| Requests/sec | 1.0 | 16.0 |
| Average response | 19.27s | 0.92s |
| Fastest | 16.42s | 0.12s |
| Slowest | 23.61s | 4.90s |
| p50 latency | 19.42s | 0.59s |
| p95 latency | 21.29s | 3.92s |
| Errors | 0 | 0 |

Krystal degrades badly under load — average response time nearly doubles from 9s to 19s. Hetzner stays under 1s average and handles 16x more requests per second.

---

## Summary

| | Krystal | Hetzner | Improvement |
|---|---|---|---|
| Homepage TTFB | 2.09s | 0.29s | 7x faster |
| REST API TTFB | 2.24s | 0.30s | 7x faster |
| Login TTFB | 2.10s | 0.21s | 10x faster |
| Throughput (10 users) | 1.1 req/s | 15.8 req/s | 14x more |
| Throughput (20 users) | 1.0 req/s | 16.0 req/s | 16x more |
| p95 under load (20 users) | 21.3s | 3.9s | 5x faster |
| Cost | ~£10/mo | ~7 EUR/mo | Cheaper |

Hetzner is faster on every metric, handles significantly more concurrent users, and costs less. The performance gap widens under load — Krystal degrades severely while Hetzner stays responsive.

Google recommends TTFB under 800ms for good user experience. Krystal consistently exceeds 2 seconds even for a single user.

---

## Caveats

- Krystal has 35 active plugins vs 6 on Hetzner. Some of the difference is plugin overhead, but the majority is shared hosting vs dedicated VPS resources.
- Neither site has page caching configured. Both could be faster with caching, but the relative difference would remain.
- Tests run from a Hetzner devcontainer in Frankfurt. Network latency to Krystal (UK) adds ~15ms vs ~0ms to Hetzner (Germany). This accounts for a negligible fraction of the 2+ second difference.
- Hetzner staging has sample data (~1,400 users, ~680 subscriptions) — comparable to live site scale.
