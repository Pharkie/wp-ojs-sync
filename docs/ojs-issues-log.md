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
