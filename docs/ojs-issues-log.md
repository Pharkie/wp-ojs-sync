# OJS Issues Log

Problems encountered with OJS during this project. Evidence for the Janeway backup evaluation.

## Install bugs

### 1. OJS 3.5.0-2: ROR dataset crash during install

The web installer crashes with `ValueError: Path cannot be empty` in `UpdateRorRegistryDataset.php`. A logic bug (`empty($pathCsv || ...)` instead of `empty($pathCsv) || ...`) lets an empty CSV path through to `fopen('', 'r')`. Fresh install is impossible on 3.5.0-2.

- **Reported:** [pkp/pkp-lib#12144](https://github.com/pkp/pkp-lib/issues/12144)
- **Fixed in:** OJS 3.5.0.3 / Docker tag `3_5_0-3`

### 2. Docker CLI install script broken for OJS 3.5

The `pkp-cli-install` script (used when `OJS_CLI_INSTALL=1`) fails silently on 3.5.x. Two bugs: missing required `timeZone` field (new in 3.5), and no session cookie (OJS 3.5 rejects the POST without one). The install appears to succeed but `installed` stays `Off`.

- **Reported:** [pkp/containers#26](https://github.com/pkp/containers/issues/26)
- **Workaround:** Our `docker/reset-ojs.sh` script handles both issues.

### 3. Failed install leaves database and config in corrupt state

If the install crashes partway through (e.g. due to bug #1), OJS sets `installed = On` in config and creates partial database tables. On next visit it tries to use the half-built database and 500s. Recovery requires three separate resets: database wipe, config flag reset, AND volume deletion. There's no self-healing or install rollback.

## Import/Export bugs

### 4. Native XML import fails on own export

Exporting issues from one OJS 3.5 instance and importing to another fails with:

> SQLSTATE[23000]: Integrity constraint violation: 1452 Cannot add or update a child row: a foreign key constraint fails (`ojs`.`submission_files`, CONSTRAINT `submission_files_source_submission_file_id_foreign`...)

The exporter writes `source_submission_file_id` references to IDs that don't exist yet in the target database. The importer doesn't resolve the ordering. This is OJS exporting data that OJS can't import.

- **Reported:** [pkp/pkp-lib#12276](https://github.com/pkp/pkp-lib/issues/12276)
- **Workaround:** Strip `source_submission_file_id` references from the XML before importing. Loses some file linkage but metadata imports fine.

## API gaps

### 5. No subscription REST API

OJS has no REST endpoints for subscription CRUD. This is why we had to build a custom plugin (`sea-subscription-api`). See `docs/ojs-api.md`.

### 6. User creation API unconfirmed

The Swagger spec shows read-only user endpoints. Creating users programmatically requires either the custom plugin or direct DB access.

## Static analysis

### 7. PHPStan cannot fully analyse OJS plugins

OJS uses a non-standard autoloader (`PKP\core\PKPContainer` + runtime classmap) that PHPStan can't resolve without booting the full application. Running PHPStan on the `sea-subscription-api` plugin produces ~70 false positives:

- **`Response::HTTP_*` constants** (~40): `Illuminate\Http\Response` extends Symfony's `Response` which defines these. PHPStan can't find them because the Symfony package lives inside `laravel/framework/src/Illuminate` rather than as a standalone vendor package.
- **DAO magic methods** (~15): `IndividualSubscriptionDAO::updateObject()`, `getByUserIdForJournal()`, etc. exist via OJS's `__call` delegation but aren't visible to static analysis.
- **Unscanned classes** (~10): `AccessKeyManager`, `APIRouter::registerPluginApiControllers()` — exist at runtime but live in directories PHPStan doesn't scan.
- **Intentional `method_exists()` checks** (~5): The `/preflight` endpoint deliberately checks whether OJS methods exist for version compatibility. PHPStan correctly notes they always return true on 3.5 — that's the point.

**One real bug found:** `authorize()` method on `SeaApiController` shadowed `PKPBaseController::authorize()` with a different signature. Renamed to `checkAuth()`.

**How to run:** Download `phpstan.phar` into the OJS container (no Composer available), point at the OJS autoloader, and provide a bootstrap file defining `PKP_STRICT_MODE`:

```bash
docker compose exec ojs bash -c "
  curl -sL https://github.com/phpstan/phpstan/releases/latest/download/phpstan.phar -o /tmp/phpstan.phar
  echo '<?php define(\"PKP_STRICT_MODE\", false);' > /tmp/phpstan-bootstrap.php
  cat > /tmp/phpstan.neon << 'NEON'
parameters:
    bootstrapFiles:
        - /tmp/phpstan-bootstrap.php
    level: 5
    paths:
        - /var/www/html/plugins/generic/seaSubscriptionApi
    scanDirectories:
        - /var/www/html/lib/pkp/classes
        - /var/www/html/classes
        - /var/www/html/lib/pkp/lib/vendor/laravel/framework/src/Illuminate
    scanFiles:
        - /var/www/html/lib/pkp/includes/functions.php
NEON
  php /tmp/phpstan.phar analyse --configuration=/tmp/phpstan.neon --no-progress --memory-limit=1G
"
```
