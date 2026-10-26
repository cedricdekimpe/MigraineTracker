# Migraine Tracker

A free migraine diary that follows the paper calendar neurologists hand out: three months per sheet, a letter and an
intensity per day, a mark for each treatment taken. Made by one person, for people who live with migraine.

Hosted version: **https://migraine-tracker.eu** (French and English) · [Version française](README.fr.md)

> Migraine Tracker is a personal tracking tool. It gives no diagnosis and does not replace a doctor.

## What it does

- **Note an attack in two taps** ("J'ai mal"): type, then intensity, in a dark screen made for the moment it hurts.
  It works without an account for a first attack, and without network (the attack is sent when the network is back).
- **The paper calendar, faithfully**: the same rows and letters (M, T, aura, X, t), three months at a time, on a phone or a
  large screen.
- **A PDF report for the consultation** that reproduces the calendar, with a summary of the year.
- **Reminders of treatment limits** (days a month by drug class, from published guidelines), and what the figures mean.
  Never a diagnosis.
- **An optional daily check-in** (sleep, stress, meals, caffeine) to see over time what comes before attacks, and the
  effect of each treatment as you note it.
- Installable as an app (PWA), dark and light themes, export and import of all your data, account deletion.

## Principles

- No advertising, no subscription, no resale of data, no trackers, no third-party scripts, fonts or images.
- No AI in the tool itself: it does simple calculations on your own days.
- [Why it is free](https://migraine-tracker.eu/en/why-free) · [A word about AI](https://migraine-tracker.eu/en/about-ai)

## Running it

Rails 8.1, Ruby 3.4, SQLite, Hotwire, Tailwind, Devise. Everything runs in Docker, nothing to install on your machine.

```sh
bin/docker-dev bin/rails db:prepare                # prepare the database
bin/docker-dev bin/rails tailwindcss:build         # build the stylesheet
bin/docker-dev bin/rails server -b 0.0.0.0         # the app on http://localhost:3000
bin/docker-dev bin/rails test                      # tests
TTY_FLAGS=-i bin/docker-dev bash -c "RAILS_ENV=test bin/rails test:system"
```

Checks used before each release: `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`.

**Self-hosting.** The production image is a single container with one SQLite volume (see `Dockerfile`), configured with
environment variables: `SECRET_KEY_BASE` (required), `APP_HOST`, and `SMTP_*` / `MAIL_FROM` for password-reset mail
(optional). A step-by-step self-hosting guide is not written yet; `docs/BACKUP.md` describes how the hosted version is
backed up. If you host your own copy you are the data controller for it: write your own privacy policy (the texts in
`config/locales` name the operator of the hosted version).

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). Questions: contact@migraine-tracker.eu

## Licence

Copyright (C) 2026 Cédric Dekimpe. Released under the [GNU Affero General Public License v3.0](LICENSE): you may read,
use, modify and share the code; if you run a modified version as a service, you must offer its source to its users. The
name "Migraine Tracker" and its logo are not covered by the licence: please pick another name for your own version.
