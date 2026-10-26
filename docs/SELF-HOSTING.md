# Self-hosting Migraine Tracker

You can run your own copy: for yourself, your family, or a small group. It is one container and one folder of data.
The code is under the AGPL-3.0 licence (see `LICENSE`): you may use and change it; if you offer a modified version to
other people over a network, you must give them its source.

**You become the person responsible for the data in your copy** (it is health data). Read the privacy section below.
The author of the software has no access to your copy and gives no support or warranty.

## What you need
- A machine that stays on, with Docker and Docker Compose (a small VPS or a home server is plenty: SQLite, one process).
- A domain name and a TLS reverse proxy in front (Caddy, Traefik, nginx...). The app must be served over https.
- Optional: a mailbox (SMTP) so that "forgot my password" can send a mail.

## 1. Get the files
```sh
mkdir migraine-tracker && cd migraine-tracker
curl -fsSLO https://raw.githubusercontent.com/cedricdekimpe/MigraineTracker/main/docker-compose.yml
curl -fsSL  https://raw.githubusercontent.com/cedricdekimpe/MigraineTracker/main/.env.selfhost.example -o .env
```

## 2. Edit `.env`
- `SECRET_KEY_BASE`: `openssl rand -hex 64`. Keep a copy somewhere safe, away from the data backups.
- `APP_HOST`: your public address, without `https://`.
- `OPERATOR_NAME` and `CONTACT_EMAIL`: who runs this copy. The privacy page shows them and warns visitors if they are empty.
- `SIGNUPS=closed` once you and your people have accounts (a personal copy should not take strangers).
- `SMTP_*` and `MAIL_FROM`: optional mail. Without `SMTP_PASSWORD`, nothing is ever sent.
- To try it on your own machine over plain http first, set `FORCE_SSL=false` and open http://localhost:3000.

## 3. Start it
```sh
docker compose up -d
docker compose logs -f        # "Listening on http://0.0.0.0:3000"; Ctrl-C leaves the logs, not the app
```
The container listens on `127.0.0.1:3000` only. Create your account at `/` (the sign-up page), then close the sign-ups if you
want (step 2, `docker compose up -d` again).

## 4. Put https in front
With Caddy, a two-line `Caddyfile` is enough (Caddy gets the certificate by itself):
```
migraine.example.org {
    reverse_proxy 127.0.0.1:3000
}
```
Then set `FORCE_SSL=true` (the default) in `.env`.

## Backups
Everything is in the Docker volume `migraine_storage` (`production.sqlite3` is the one that matters). A consistent copy while
the app runs:
```sh
docker compose exec migraine-tracker bundle exec ruby -e '
  require "sqlite3"
  SQLite3::Database.new("/rails/storage/production.sqlite3").execute("VACUUM INTO ?", ["/tmp/backup.sqlite3"])'
docker compose cp migraine-tracker:/tmp/backup.sqlite3 ./backup-$(date +%F).sqlite3
docker compose exec migraine-tracker rm /tmp/backup.sqlite3
```
Keep these copies encrypted and off the machine. To restore: stop the app, put the file back as
`/rails/storage/production.sqlite3` in the volume, start it.
Each user can also export their own data from Account, then Data.

## Updating
```sh
docker compose pull && docker compose up -d
```
Database migrations run by themselves when the container starts. Read the release notes first if you skip versions, and
back up before.

## Privacy: what you owe your users
- The privacy page of your copy describes what the software keeps and shows your name and contact (step 2). It does not repeat
  what the hosted service says about its own server, backups or mail provider: write down yours (where the server is, how long
  backups live, who sends your mail) in your own words, next to or instead of that page.
- Health data is a special category under the GDPR: you need a legal basis (here, the explicit consent users give when they
  create their account) and you must be able to export and delete a person's data (both exist in the app).
- Do not give the data to anyone, and keep the machine and its backups secure.

## Good to know
- No analytics, no tracker, no outside script: nothing in the app calls another site. Your mail provider, if you set one, sees
  the address and the message of password-reset mails.
- The name "Migraine Tracker" and the logo are not covered by the licence: if you change the software, pick your own name.
- A security problem in the software itself: see `SECURITY.md`.
