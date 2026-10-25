# Backups of the production database

What must survive: the SQLite database `storage/production.sqlite3` (Docker volume `my_migraine_manager_storage` on the
VPS). The queue, cache and cable databases are rebuilt by themselves. `SECRET_KEY_BASE` lives in
`~/.config/migrainetracker/app.env` (copy in the owner's password manager, never next to the backups): without it nobody
stays signed in, but the data stays readable (nothing is encrypted with it).

```
VPS (deploy)                    homelab                              BorgBase (off-site, encrypted)
~/backups-migraine/db  <-rsync- ~/backups/migrainetracker  -borgmatic-> archives "migrainetracker-*", 30 days
   ^ snapshot (VACUUM INTO)      cron 04:30 (script/backup/pull)
```

The backups hold health data. They stay on the owner's machines and in the encrypted BorgBase repository, never anywhere
else, and the privacy policy says it ("Durée de conservation": kept 30 days, so a deleted account leaves the backups
within 30 days).

- `script/backup/vps-snapshot` (installed as `~/bin/migraine-snapshot` on the VPS): a consistent copy of the database
  taken while the site runs (`VACUUM INTO`, then `PRAGMA integrity_check`), the last 3 kept.
- `script/backup/vps-gate` (`~/bin/migraine-backup-gate`): the *forced command* of a dedicated key,
  `~/.ssh/migraine_backup_ed25519` on the homelab. In `authorized_keys` of `deploy`:
  `command="/home/deploy/bin/migraine-backup-gate",restrict ssh-ed25519 ...`. That key can only run the snapshot and read
  `~/backups-migraine` through `rrsync -ro`; anything else answers "denied". It is not the deployment key.
- `script/backup/pull` (homelab, cron daily 04:30, log `~/backups/migrainetracker.log`): asks for a snapshot, mirrors it
  with `rsync --delete`, checks the database copy, then pings the Uptime Kuma push monitor "migraine-tracker backup"
  (URL in `~/.config/migrainetracker/backup-push-url`; down after 26 hours without a heartbeat).
- borgmatic: `/etc/borgmatic.d/migrainetracker.yaml`, its own archive series with `keep_daily: 30`, in the same BorgBase
  repository as the rest of the homelab, no repository check (the main configuration runs it).

## Restore
1. Pick a snapshot: `borgmatic list --archive latest -c /etc/borgmatic.d/migrainetracker.yaml` or take
   `~/backups/migrainetracker/db/`.
2. Stop the app (`script/deploy app stop`), copy the file into the volume as `storage/production.sqlite3` (remove the
   `-wal` and `-shm` files of the old one), start the app (`script/deploy app boot`).
3. Check `/up`, the sign-in page and one account. Migrations run at boot, so an older snapshot is brought up to date.

Restore drill: restore to a throw-away directory, open the copy with the app and count the users and episodes
(`DATABASE_URL=sqlite3:/path/copy.sqlite3 bin/rails runner 'p User.count, Episode.count'`).
