# Reclaiming the Git LFS storage in `sea-ojs-private`

**Status: PREPARED, NOT RUN.** Every command below is destructive in a way that
needs a decision first. Nothing here has been executed.

## What is actually stored

Measured 2026-08-29 from a pointer-only clone (`GIT_LFS_SKIP_SMUDGE=1`), across
all refs:

| Path | Objects | Size |
|---|---:|---:|
| `backups/**/*.sql.gz.enc` | 156 | **11.06 GB** |
| `backfill/**/*.pdf` (journal PDFs) | 1,579 | 0.62 GB |
| **Total** | 1,735 | **11.68 GB** |

Every object id is distinct, so there is no deduplication to recover. GitHub was
reporting ~90% of the 10 GB free allowance around the same date; treat the exact
figure as approximate and the ratio as the point. **The nightly database dumps
are ~95% of the storage.** The journal PDFs are a rounding error and should stay.

The dumps arrived through `.github/workflows/backup.yml`, which pulled the
previous night's encrypted dump off the box and committed it through LFS. It
pruned the working tree to 30 daily — which is why the repo looked small and the
bill did not.

That workflow was **disabled on 2026-08-29** and the off-site copy now goes to
Cloudflare R2 instead (`scripts/ojs/upload-backup-r2.sh`, and the *Off-site
backups* section of [`setup-guide.md`](setup-guide.md)). Nothing new is being
added to LFS. What follows is only about the 11 GB already there.

## 🛑 The thing that makes this awkward

**Rewriting history does not reclaim any storage.** This is the trap, and it is
the opposite of what everyone expects:

> After you remove files from Git LFS, the Git LFS objects still exist on the
> remote storage and will continue to count toward your Git LFS storage quota.
> — [GitHub Docs](https://docs.github.com/en/repositories/working-with-files/managing-large-files/removing-files-from-git-large-file-storage)

`git filter-repo` or BFG plus a force push removes the **pointers**. The objects
stay in GitHub's LFS store, and there is no API, UI or `git` command that deletes
them. GitHub names exactly two routes: **delete and recreate the repository**, or
**ask Support to purge them**.

So "rewrite the history and force-push" is not a smaller version of this job. It
is a job that achieves nothing on its own, and it would still be true after it
had thrown the history away.

One more billing detail worth knowing before picking a date: deleting objects
part-way through a month does not recalculate that month. The usage figure moves
on the 1st.

## Option A — delete and recreate the repository (reclaims everything)

Net LFS afterwards ≈ **0.62 GB** (the journal PDFs, re-pushed).

**What it destroys**, checked against the live repo on 2026-08-29:

- **9 Actions secrets.** They cannot be read back out of GitHub. Eight are
  recoverable: `SSH_PRIVATE_KEY` is `~/.ssh/hetzner-backup` on Adam's Mac
  (fingerprint verified against `github-actions-backup` in the box's
  `authorized_keys`); `CADDY_WP_AUTH_PASS`, `BETTERSTACK_HB_DAILY`,
  `BETTERSTACK_HB_HOURLY`, `LIVE_OJS_URL` and `LIVE_WP_HOME` are all in the
  box's `/opt/pharkie-ojs-plugins/.env`; `VPS_HOST` is the box; `KNOWN_HOSTS`
  rebuilds with `ssh-keyscan`.

  🛑 **`SSH_MONITOR_KEY` IS NOT RECOVERABLE, and deleting the repo destroys it.**
  Checked 2026-08-29: the `github-actions-monitor` entry in the box's
  `authorized_keys` has fingerprint `SHA256:kGf1TgKs1GGKYrGBvb/zaq0p1nSZI23fCuXz341/fi0`,
  which matches **none** of the seven keys on Adam's Mac, and no key material
  exists anywhere in this repo or the private one. The private half lives only
  inside the GitHub secret, and a secret is write-only.

  This is fixable but it is WORK, and it must happen in the same sitting:
  generate a new keypair, add the public half to the box, then set the private
  half as the new repo's secret. Copy the restriction verbatim — the existing
  line is `command="/usr/local/bin/monitor-shell.sh",restrict`, and a key added
  without it is an unrestricted root login rather than a monitoring key.

  ```bash
  ssh-keygen -t ed25519 -N '' -C github-actions-monitor-v2 -f ~/.ssh/hetzner-monitor
  ssh sea-live "printf 'command=\"/usr/local/bin/monitor-shell.sh\",restrict %s\n' \
    \"$(cat ~/.ssh/hetzner-monitor.pub)\" >> /root/.ssh/authorized_keys"
  ssh -i ~/.ssh/hetzner-monitor root@<box> true      # PROVE IT WORKS FIRST
  # …then, and only then, delete the repo. Afterwards:
  gh secret set SSH_MONITOR_KEY -R Pharkie/sea-ojs-private < ~/.ssh/hetzner-monitor
  ```

  Prove the new key works **before** anything is deleted. Testing it afterwards
  means discovering a typo with the monitoring already down and no old key to
  fall back on.
- **One closed PR** (`chore: Configure Renovate`) and all workflow run history.
- Nothing else: no issues, no forks, no stars, no deploy keys, no branch
  protection, one branch.

🛑 **The real risk is not the repo, it is the monitoring.** Three of the four
workflows there are live: `monitor-daily.yml`, `monitor-rerun.yml` and
`rebuild-smarter-similar-articles.yml`. Between deleting the repo and re-adding
the secrets, the OJS/WP checks are silently not running and their Better Stack
heartbeats will go red. Do this in one sitting, and expect the heartbeat alerts.

### The commands

```bash
# 1. Pointer-only clone, then strip backups/ — and fetch the PDF objects AFTER
#    the strip, so only the 0.62 GB we intend to keep is downloaded.
#
# 🛑 DO NOT `git lfs fetch --all` BEFORE THE STRIP. The free tier gives 10 GB of
#    BANDWIDTH a month as well as 10 GB of storage, so pulling the 11.68 GB of
#    history would blow the bandwidth quota and block the very push in step 4.
#    It also means the historical dumps are GONE, not archived — which is the
#    decision being taken here, and it should be taken deliberately.

# 2. Strip backups/ from every commit, then pull down what remains.
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/Pharkie/sea-ojs-private.git clean
cd clean
git filter-repo --path backups --invert-paths          # pipx install git-filter-repo
sed -i '/^backups\//d' .gitattributes
git add .gitattributes && git commit -m "Drop the LFS backup tracking; off-site is R2 now"
git remote add origin https://github.com/Pharkie/sea-ojs-private.git
git lfs ls-files --all | wc -l                          # expect 1579, all backfill PDFs
git lfs fetch --all                                     # ~0.62 GB now the dumps are gone
git lfs fsck --pointers                                 # must say OK before step 3

# 3. Delete the repository. THIS IS THE IRREVERSIBLE STEP.
gh repo delete Pharkie/sea-ojs-private --yes

# 4. Recreate and push.
gh repo create Pharkie/sea-ojs-private --private
git remote set-url origin https://github.com/Pharkie/sea-ojs-private.git
git push --all && git push --tags

# 5. Re-add the nine secrets, then confirm the monitors run.
gh secret set SSH_PRIVATE_KEY -R Pharkie/sea-ojs-private < ~/.ssh/hetzner-backup
# … and the other eight …
gh workflow run monitor-daily.yml -R Pharkie/sea-ojs-private
```

Storage does not drop instantly — reports of a 17 GB repo taking about fifteen
minutes. Check the account's billing page rather than assuming it failed.

Keep `lfs-rescue.git` until the new repo has been verified end to end.

## Option B — ask GitHub Support to purge the objects

Non-destructive: the repo, its secrets, its history and its run logs all survive.
Rewrite the history first (step 2 above, force-pushed), then open a ticket
quoting the "unable to delete the repository" line from the doc linked above and
naming `backups/**/*.sql.gz.enc`.

Slower and not guaranteed — but it is the only option that does not take the
monitoring down, and there is no deadline now that nothing new is being added.

## Option C — buy a data pack

$5/month per 50 GB. Removes the problem without removing the data, and pays
indefinitely to store database dumps that R2 now holds anyway. Worth naming only
so that "do nothing" is a considered choice rather than a default.

**Steps 1 and 2 have already been run** (2026-08-29) and the result is sitting in
this session's scratchpad: 156 backup pointers removed, all 1,579 backfill PDF
objects fetched and `git lfs fsck` clean. It is a scratch directory, so treat it
as saving an hour rather than as a thing to depend on — the commands above
reproduce it from scratch in about five minutes.

## Recommendation

**B, then A if Support declines.** The urgency ended when the workflow was
disabled: nothing is growing, and the only cost of waiting is the allowance
sitting full. That makes the option that keeps the monitoring up the better
trade, even though it is slower — and if it fails, A is still there and the
rescue clone from step 1 makes it safe.
