# Mobile app API (v1)

The JSON API that the Migraine Tracker mobile app uses. It is small on purpose: the app keeps a copy of the
journal (episodes, cycle days, daily check-ins) to work offline, and shows the other screens from the web site.
Since server version 1.3.0.

- Base URL: `https://{server}/api/v1`. JSON in, JSON out.
- Every call except sign-in carries `Authorization: Bearer {token}`.
- Errors are codes, never sentences: `{ "error": "unauthorized" }`, and validation errors such as
  `{ "occurred_on": ["future"] }`. The app writes the words.
- Dates are `YYYY-MM-DD`, times of day `HH:MM`, instants ISO 8601 with microseconds. Dates are the journal's
  days, as on the web; times are in the server's time zone (Europe/Brussels on the hosted service).

## Before signing in: `GET /.well-known/migraine-tracker.json`

No token. Who runs this server and what it can do, so that the app can check a self-hosted address:

```json
{
  "name": "Migraine Tracker",
  "version": "1.3.0",
  "api": { "versions": ["v1"], "url": "https://example.org/api/v1" },
  "app": { "minimum_version": "1.0.0" },
  "official": false,
  "operator": { "name": "…", "contact": "…" },
  "signups_open": true,
  "locales": ["en", "fr"],
  "privacy_url": { "en": "…", "fr": "…" },
  "path_configuration": { "android": "https://example.org/configurations/android_v1.json" }
}
```

## Signing in and out

| Call | Body | Answer |
|---|---|---|
| `POST /session` | `{ "email", "password", "device_name" }` | `201 { "token", "device_id", "user": { "email", "track_cycle" } }`, or `401 { "error": "invalid_credentials" }` (same answer for an unknown address) |
| `GET /me` | — | `{ "device_id", "user" }`: checks that the token still works |
| `DELETE /session` | — | `204`: signs this device out |
| `POST /session/web_code` | — | `{ "code", "expires_in": 60 }`: see below |

The token is shown once; the server keeps only its digest. The account lists its devices (Account, Profile) and
can sign any of them out, which makes its token fail with `401`. Sign-ins are throttled: 10 a minute per IP,
8 every 10 minutes per address; the whole API, 300 requests every 5 minutes per IP (`429`).

Accounts are created on the web site: the API has no sign-up.

### The app's web screens

To open a web screen signed in, the app asks `POST /session/web_code`, then loads
`https://{server}/app/session?code={code}&to=/fr/stats` in its web view. The code works once, for one minute,
and opens an ordinary web session; `to` must be a path of the site.

## The journal: `GET /changes` and `POST /changes`

### Pull

`GET /changes` sends the whole journal; `GET /changes?since={cursor}` what changed since a previous answer's
`cursor`. Records are sent whole and may come twice (a few seconds of overlap around the cursor): replace your
copy by `uuid`.

```json
{
  "cursor": "2026-11-05T19:30:00.123456+01:00",
  "full": false,
  "episodes": [{
    "uuid": "…", "occurred_on": "2026-11-05", "started_time": "07:15", "duration_minutes": 240,
    "aura": false, "pain_kind": "migraine", "intensity": 8, "nausea": "nausea", "notes": null,
    "ongoing": false, "trigger_ids": [3],
    "medication_intakes": [{ "uuid": "…", "medication_id": 12, "dose": "400 mg", "taken_time": "07:30", "effect": "good" }],
    "updated_at": "…"
  }],
  "period_days": [{ "uuid": "…", "date": "2026-11-02", "updated_at": "…" }],
  "daily_checks": [{ "uuid": "…", "date": "2026-11-05", "sleep": "short", "stress": "high", "skipped_meal": false, "caffeine": "usual", "updated_at": "…" }],
  "deletions": [{ "type": "episode", "uuid": "…", "deleted_at": "…" }],
  "medications": [{ "id": 12, "name": "Ibuprofène", "kind": "acute", "default_dose": "400 mg", "archived": false }],
  "triggers": [{ "id": 3, "name": "Stress", "key": "stress" }]
}
```

Medications and triggers are always sent whole (they are short lists) and are managed on the web.

Allowed values: `pain_kind` migraine, headache or null (then `aura` must be true); `intensity` 1 to 10, required
with pain; `nausea` none, nausea, vomiting; `effect` none, partial, good; `sleep` good, fragmented, short;
`stress` low, medium, high; `caffeine` none, usual, high.

### Push

`POST /changes` with any of `episodes`, `period_days`, `daily_checks` (same shape as above) and
`deletions` (`{ "type", "uuid", "deleted_at" }`), 500 records at most (`413` beyond).

- The phone chooses the `uuid` of what it creates (UUID v4): sending the same record twice updates it.
- `updated_at` is when the phone made the change. The most recent version wins: if the server's copy changed
  later, the record is not applied (`stale`) and the next pull brings the server's copy. A clock in the future
  counts as now.
- An episode's `medication_intakes` are its whole list: intakes left out are removed. Fields left out of an
  existing record keep their value.
- Only the account's own medications and triggers can be used.

Answer: one result per record, in order:

```json
{ "results": [
  { "type": "episode", "uuid": "…", "status": "saved" },
  { "type": "episode", "uuid": "…", "status": "invalid", "errors": { "occurred_on": ["future"] } },
  { "type": "period_day", "uuid": "…", "status": "merged", "uuid_now": "…" }
] }
```

| Status | Meaning |
|---|---|
| `saved` | created or updated |
| `unchanged` | nothing to change |
| `stale` | the server's copy is more recent and was kept |
| `merged` | the same day already exists under another `uuid` (cycle day, daily check-in): use `uuid_now` from now on |
| `invalid` | see `errors` (codes); `uuid: ["taken"]` when the uuid belongs to another record |
| `deleted` / `gone` | deletion done / the record was already gone |

## Versions

The API is versioned in its path. Compatible additions (a new field, a new call) keep `v1`; anything else
becomes `v2`, with `v1` kept long enough for the apps to update. The app refuses a server older than it needs
(`version` in the server description) and a server refuses an app older than `app.minimum_version`.
