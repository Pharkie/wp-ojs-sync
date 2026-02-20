# Draft GitHub issue for pkp/containers

**Title:** `pkp-cli-install` fails on OJS 3.5 — missing `timeZone` field and no session cookie

**Labels:** bug

---

## Description

The [`pkp-cli-install`](https://github.com/pkp/containers/blob/main/templates/pkp/root/usr/local/bin/pkp-cli-install) script (used when `OJS_CLI_INSTALL=1`) fails silently on OJS 3.5.x images. The install POST returns a 302 redirect and OJS remains in `installed = Off` state.

Two bugs in `templates/pkp/root/usr/local/bin/pkp-cli-install`:

### 1. Missing `timeZone` parameter

OJS 3.5 added a required `timeZone` field to the install form. The script doesn't include it, so the install fails with:

> Errors occurred during installation
> A time zone must be selected.

### 2. No session cookie

The script POSTs directly without first loading the install page to get a session cookie. OJS 3.5 rejects the POST with a 302 redirect back to the install page.

## Steps to reproduce

```bash
docker run -d --name ojs-db \
    -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=ojs \
    -e MYSQL_USER=ojs -e MYSQL_PASSWORD=ojs \
    mariadb:10.11

# Wait for DB to be ready, then:
docker run -d --name ojs --link ojs-db \
    -e OJS_CLI_INSTALL=1 \
    -e OJS_DB_HOST=ojs-db -e OJS_DB_USER=ojs \
    -e OJS_DB_PASSWORD=ojs -e OJS_DB_NAME=ojs \
    -p 8081:80 pkpofficial/ojs:3_5_0-3

# Wait ~30s for startup, then check:
docker exec ojs grep "installed = " /var/www/html/config.inc.php
# Expected: installed = On
# Actual:   installed = Off
```

## Affected images

- `pkpofficial/ojs:3_5_0-3` (OJS 3.5.0.3)
- Likely all 3.5.x images

## Suggested fix

In `templates/pkp/root/usr/local/bin/pkp-cli-install`:

1. Add `&timeZone=UTC` (or read from `$TZ` env var) to the POST data
2. Fetch the install page first to establish a session, then POST with that cookie
3. Verify `installed = On` in config after the POST and log an error if it failed

```sh
#!/bin/sh

echo "[PKP CLI Install] First time running this container, preparing..."
echo "127.0.0.1 ${SERVERNAME}" >> /etc/hosts

TIMEZONE="${TZ:-UTC}"

echo "[PKP CLI Install] Getting session cookie..."
curl -sc /tmp/ojs-install-cookies "https://${SERVERNAME}/index/en/install" -o /dev/null

echo "[PKP CLI Install] Running install..."
curl -sb /tmp/ojs-install-cookies -L "https://${SERVERNAME}/index/en/install/install" \
    --data "installing=0&adminUsername=admin&adminPassword=admin&adminPassword2=admin&adminEmail=admin%40${SERVERNAME}.org&locale=en_US&additionalLocales%5B%5D=en_US&clientCharset=utf-8&connectionCharset=utf8&databaseCharset=utf8&filesDir=%2Fvar%2Fwww%2Ffiles&databaseDriver=mysql&databaseHost=${PKP_DB_HOST}&databaseUsername=${PKP_DB_USER}&databasePassword=${PKP_DB_PASSWORD}&databaseName=${PKP_DB_NAME}&oaiRepositoryId=${SERVERNAME}&enableBeacon=0&timeZone=${TIMEZONE}" \
    --compressed

if grep -q "installed = On" "${PKP_CONF}"; then
    echo "[PKP CLI Install] DONE!"
else
    echo "[PKP CLI Install] ERROR: Install failed. Check logs."
    exit 1
fi

rm -f /tmp/ojs-install-cookies
```
