# Docker Quick Reference

## Versions

| Service | Image | App version | Notes |
|---------|-------|-------------|-------|
| WordPress | `wordpress:6.9.1-php8.2-apache` | WP 6.9.1, PHP 8.2 | Matches live |
| OJS | `pkpofficial/ojs:3_5_0-3` | OJS 3.5.0.3, PHP 8.3 | Matches staging |
| MariaDB (both) | `mariadb:10.11` | 10.11 | — |

Do not use Docker tag `3_5_0-2` — it has a [known install bug](https://github.com/pkp/pkp-lib/issues/12144).

## URLs

| Service | Browser URL | Internal (container-to-container) |
|---------|------------|-----------------------------------|
| WordPress | http://localhost:8080 | http://wp:80 |
| OJS | http://localhost:8081 | http://ojs:80 |
| OJS API (from WP) | — | http://ojs:80/index.php/t1/api/v1/sea/... |

## Database credentials

| | WordPress | OJS |
|--|-----------|-----|
| Host | `wp-db` | `ojs-db` |
| Database | `wordpress` | `ojs` |
| User | `wordpress` | `ojs` |
| Password | `devpass123` | `devpass123` |
| Root password | `devroot123` | `devroot123` |

## OJS install

Run `./docker/reset-ojs.sh` — it installs OJS automatically, no wizard needed.

Admin login: `admin` / `admin123`

If you need to run the wizard manually (e.g. first time without the script):

| Field | Value |
|-------|-------|
| Upload directory | `/var/www/files` |
| Database driver | MariaDB |
| Host | `ojs-db` |
| Username | `ojs` |
| Password | `devpass123` |
| Database name | `ojs` |

## API key

Shared key for WP → OJS sync: `dev-api-key-local` (set in `.env`).

## Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Stop and delete all data (fresh start — both WP and OJS)
docker compose down -v

# Reset OJS only (wipes DB + volumes, reinstalls automatically — no wizard)
./docker/reset-ojs.sh

# View logs
docker compose logs -f        # all
docker compose logs -f ojs    # one service

# Shell into a container
docker compose exec wp bash
docker compose exec ojs bash

# Test WP → OJS connectivity
docker compose exec wp curl http://ojs:80/index.php/t1/api/v1/sea/ping

# Staging (on remote server)
docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d
```

## Resetting OJS

If OJS gets into a broken state (failed install, version change, corrupt DB), run:

```bash
./docker/reset-ojs.sh
```

This handles everything in one shot:
1. Stops containers
2. Deletes the `ojs_data` volume (code) and `ojs_files` volume
3. Resets the OJS database
4. Starts containers (Docker repopulates volumes from the image)
5. Runs the install automatically (no wizard)

OJS admin after reset: `admin` / `admin123`

**Why all three steps matter:** OJS has state in three places — the database, the code volume (`ojs_data`), and `config.inc.php` (inside `ojs_data`). If any one of these is stale, the install will fail. The reset script handles all three.

**Changing OJS image version:** Docker does not update named volumes when you change image tags. If you change the OJS image in `docker-compose.yml`, you **must** run `./docker/reset-ojs.sh` — otherwise the old code stays in the volume and you get a version mismatch.

## Bind-mounted plugins

Edits on your host are reflected immediately in the containers:

| Host path | Container path |
|-----------|---------------|
| `plugins/sea-ojs-sync/` | WP: `/var/www/html/wp-content/plugins/sea-ojs-sync/` |
| `plugins/sea-subscription-api/` | OJS: `/var/www/html/plugins/generic/seaSubscriptionApi/` |
