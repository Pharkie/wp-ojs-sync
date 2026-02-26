# Hosting Requirements

What we need to deploy, test, and maintain the WP-OJS sync integration.

---

## Recommended provider setup

| System | Provider | Plan | Why |
|---|---|---|---|
| **OJS** | **DigitalOcean** (London region) | Droplet, 2 GB RAM / 1 vCPU / 25 GB SSD (~$12/mo) | Full root access, Docker support, UK data centre. OJS is a fresh deployment — we can specify exactly what we need. |
| **WP** | **Krystal** (existing) | Current shared hosting plan | Already running. Has SSH, WP-CLI, file access — everything the sync plugin needs. No migration required. |

The two systems communicate over standard HTTPS on the public internet. No VPN, shared network, or same-provider requirement. This is the same way WP already talks to Stripe, payment gateways, and other external services.

---

## OJS on DigitalOcean

OJS is a fresh deployment. A DigitalOcean droplet in the London region mirrors the Docker dev environment exactly and gives us full control over the server.

**Spec:** 2 GB RAM, 1 vCPU, 25 GB SSD (~$12/mo). OJS is a PHP/MySQL app with light traffic (~700 members, not concurrent). This is comfortable for staging and production. Scale up if article traffic grows significantly. Two droplets needed — one for staging, one for production.

### What DigitalOcean provides (all included with a standard droplet)

| Requirement | DigitalOcean | Notes |
|---|---|---|
| **SSH access** | Yes — root by default | Deploy plugin files, edit `config.inc.php`, restart services |
| **Docker + Docker Compose** | Yes — one-click Docker image or install manually | Run OJS the same way as dev |
| **Root access** | Yes | Full control over the server |
| **MariaDB/MySQL access** | Yes — runs in Docker container | For troubleshooting and data verification |
| **Firewall control** | Yes — UFW on server + DigitalOcean cloud firewall | Accept HTTPS on 443, restrict SSH |
| **SSL/TLS certificate** | Yes — Let's Encrypt via Caddy or nginx | HTTPS required (WP plugin rejects `http://`) |
| **DNS control** | Yes — DigitalOcean DNS or external | Point journal subdomain at droplet |
| **Automated backups** | Yes — droplet backups ($2.40/mo) or manual snapshots | Database + uploaded files, daily |

### What we configure ourselves

| Item | Detail |
|---|---|
| **SMTP relay** | Transactional email (Mailgun, SES, or Postmark) with SPF/DKIM/DMARC for the OJS sending domain. Required for welcome emails and password resets. |
| **OJS `config.inc.php`** | `[wpojs]` section: `allowed_ips` (Krystal's outbound IP), `wp_member_url`, `support_email`, `api_key_secret` |
| **OJS subscription type** | Create in OJS admin, record the `type_id` for WP plugin config |

### Docker architecture

The production Docker setup would be similar to dev but simplified (no sample data, no dev tools):

```
docker-compose.yml
├── ojs          # OJS 3.5 (Apache + PHP-FPM)
├── ojs-db       # MariaDB
└── caddy/nginx  # Reverse proxy with SSL termination
```

The OJS plugin is mounted into the container (or built into the image). Config is managed via `config.inc.php` mounted as a volume.

### What an OJS upgrade looks like

1. Pull new OJS image / rebuild container
2. Run `wp ojs-sync test-connection` from WP (calls `/preflight` to verify plugin compatibility)
3. If preflight passes: done
4. If preflight fails: check which classes/methods changed, update plugin, re-test

This is why Docker matters — you can test the upgrade on staging by rebuilding the container, verify everything works, then do the same on production. No manual PHP/Apache upgrades.

### What we do NOT need

- cPanel, Plesk, or any control panel (SSH is sufficient and preferred)
- Shared hosting (OJS needs its own server/container)
- Windows (OJS runs on Linux)

---

## WP on Krystal (existing — no migration needed)

WP stays on its current Krystal shared hosting. Krystal provides everything the sync plugin needs — no hosting changes required.

### What Krystal provides

| Requirement | Krystal shared hosting | Notes |
|---|---|---|
| **SSH access** | Yes (all plans except Amethyst) | Deploy files, run WP-CLI |
| **WP-CLI** | Yes — installed by default | Bulk sync, test connection, reconciliation |
| **WP Admin access** | Yes | Configure plugin settings, view sync log |
| **`wp-config.php` edit access** | Yes — via SSH or cPanel file manager | Add `WPOJS_API_KEY` constant (one-time) |
| **File upload to plugins dir** | Yes — SSH, SFTP, or cPanel | Deploy the `wpojs-sync` plugin |
| **Outbound HTTPS** | Yes — not restricted | WP calls OJS API over standard HTTPS |

### What we do NOT need from Krystal

- Direct database access (all WP operations go through WP-CLI and the plugin)
- Root/sudo access
- PHP version changes (plugin works with PHP 7.4+, Krystal supports this)
- Server configuration changes (no Apache/nginx changes on the WP side)

### WP server IP

The OJS API uses an IP allowlist. We need to know the WP server's outbound IP address. The plugin settings page displays this, or run:

```bash
wp eval 'echo file_get_contents("https://api.ipify.org");' --allow-root
```

This IP goes into OJS `config.inc.php` under `[wpojs] allowed_ips`.

### Verifying access

Once we have access, the first thing to run:

```bash
# Check WP-CLI works
wp --info

# Check outbound connectivity to OJS (replace with actual OJS URL)
wp eval 'echo wp_remote_retrieve_response_code(wp_remote_get("https://journal.example.org/api/v1/wpojs/ping"));'

# Deploy plugin and test
wp ojs-sync test-connection
```

---

## How the two systems connect

Krystal (WP) and DigitalOcean (OJS) communicate over standard HTTPS on the public internet. No VPN, shared network, or same-provider requirement.

Configuration needed:

1. **WP side (Krystal):** Set the OJS URL in plugin settings (e.g. `https://journal.example.org/index.php/journal`) and add `WPOJS_API_KEY` to `wp-config.php`
2. **OJS side (DigitalOcean):** Add Krystal's outbound IP to `allowed_ips` in `config.inc.php` and set the same API key

To find Krystal's outbound IP:

```bash
wp eval 'echo file_get_contents("https://api.ipify.org");' --allow-root
```

The `test-connection` command verifies end-to-end connectivity, auth, and IP allowlisting in one step.

---

## Staging vs production

Both environments need the same access. Deploy to staging first, smoke test with a few users, then repeat on production.

| Step | Staging | Production |
|---|---|---|
| Deploy OJS plugin | Yes | After staging verified |
| Deploy WP plugin | Yes | After staging verified |
| Configure both sides | Yes | Same config, different URLs/IPs/keys |
| `test-connection` | Yes | Yes |
| Sync 5-10 test users | Yes | Skip (go straight to dry-run) |
| `sync --dry-run` | Yes | Yes |
| `sync` (bulk) | Yes | After dry-run reviewed |
| `send-welcome-emails` | Test with 1-2 addresses | After bulk sync verified |

The launch sequence in [`plan.md`](./plan.md) has the full checklist.
