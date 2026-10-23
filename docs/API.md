# MigraineTracker API Documentation

This document describes the REST API for the MigraineTracker application. The API follows the JSON API specification and uses JWT for authentication.

## Base URL

```
/api/v1
```

## Authentication

The API uses JWT (JSON Web Token) for authentication. Tokens are passed via the `Authorization` header.

### Getting a Token

1. **Register** a new account or **Login** to get a JWT token
2. The token is returned in the `Authorization` header as `Bearer <token>`
3. Include this token in all subsequent requests

### Token Expiration

- **Access tokens** expire after 1 hour
- Use the **refresh endpoint** to get a new token before expiration

### Headers

All authenticated requests must include:

```
Authorization: Bearer <your-jwt-token>
Content-Type: application/json
Accept: application/vnd.api+json
```

---

## Rate Limiting

- **Authenticated requests**: 100 requests/minute per user
- **Authentication endpoints**: 10 requests/minute per IP
- **Unauthenticated requests**: 100 requests/minute per IP

Rate limit headers are included in responses:
- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Requests remaining
- `X-RateLimit-Reset`: Unix timestamp when limit resets

---

## Error Responses

All errors follow the JSON API error format:

```json
{
  "errors": [
    {
      "status": "422",
      "title": "Unprocessable Entity",
      "detail": "Email has already been taken",
      "source": {
        "pointer": "/data/attributes/email"
      }
    }
  ]
}
```

Common HTTP status codes:
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (missing/invalid token)
- `404` - Not Found
- `422` - Unprocessable Entity (validation errors)
- `429` - Too Many Requests (rate limited)

---

## Authentication Endpoints

### Register

Create a new user account.

```
POST /api/v1/auth/register
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123",
  "password_confirmation": "securepassword123"
}
```
The request must also include `"health_data_consent": true` to confirm you accept the storage of your health data (episodes, medications, triggers) under the privacy policy.

**Response:** `201 Created`
```json
{
  "data": {
    "id": "1",
    "type": "user",
    "attributes": {
      "email": "user@example.com",
      "created_at": "2026-02-17T14:00:00Z",
      "updated_at": "2026-02-17T14:00:00Z",
      "episodes_count": 0,
      "medications_count": 0
    }
  }
}
```

**Response Headers:**
```
Authorization: Bearer <jwt-token>
```

---

### Login

Authenticate and receive a JWT token.

```
POST /api/v1/auth/login
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**Response:** `200 OK`
```json
{
  "data": {
    "id": "1",
    "type": "user",
    "attributes": {
      "email": "user@example.com",
      "created_at": "2026-02-17T14:00:00Z",
      "updated_at": "2026-02-17T14:00:00Z",
      "episodes_count": 5,
      "medications_count": 2
    }
  }
}
```

**Response Headers:**
```
Authorization: Bearer <jwt-token>
```

---

### Logout

Revoke the current JWT token.

```
DELETE /api/v1/auth/logout
```

**Headers:** Authorization required

**Response:** `200 OK`
```json
{
  "meta": {
    "message": "Successfully logged out."
  }
}
```

---

### Refresh Token

Get a new JWT token (before the current one expires).

```
POST /api/v1/auth/refresh
```

**Headers:** Authorization required

**Response:** `200 OK`

**Response Headers:**
```
Authorization: Bearer <new-jwt-token>
```

---

### Get Current User

Get the currently authenticated user's information.

```
GET /api/v1/auth/me
```

**Headers:** Authorization required

**Response:** `200 OK`
```json
{
  "data": {
    "id": "1",
    "type": "user",
    "attributes": {
      "email": "user@example.com",
      "created_at": "2026-02-17T14:00:00Z",
      "updated_at": "2026-02-17T14:00:00Z",
      "episodes_count": 5,
      "medications_count": 2
    }
  }
}
```

---

## User Profile Endpoints

### Get Profile

```
GET /api/v1/user/profile
```

**Headers:** Authorization required

**Response:** `200 OK` (same as `/auth/me`)

---

### Update Profile

Update email or password.

```
PATCH /api/v1/user/profile
```

**Headers:** Authorization required

**Request Body (email change):**
```json
{
  "email": "newemail@example.com"
}
```

**Request Body (password change):**
```json
{
  "current_password": "oldpassword123",
  "password": "newpassword456",
  "password_confirmation": "newpassword456"
}
```

**Response:** `200 OK`

---

### Delete Account

Permanently delete the user account and all associated data.

```
DELETE /api/v1/user
```

**Headers:** Authorization required

**Request Body:**
```json
{
  "confirmation_phrase": "DELETE MY ACCOUNT",
  "password": "yourpassword"
}
```

**Response:** `200 OK`
```json
{
  "meta": {
    "message": "Your account and all associated data have been permanently deleted."
  }
}
```

---

## Episodes Endpoints

An **episode** is one headache-type event. A day can have several. It has pain (`pain_kind`:
`migraine` or `headache`, or none), an independent `aura` flag (an aura can precede a migraine
or happen alone), an `intensity` from 1 to 10 (required with pain, empty without), and optional
start time, duration, notes and cycle flag. At least one of aura or pain is required.

Episode resource:

```json
{
  "id": "12",
  "type": "episode",
  "attributes": {
    "occurred_on": "2026-02-10",
    "started_time": "08:30",
    "duration_minutes": 240,
    "aura": true,
    "pain_kind": "migraine",
    "intensity": 7,
    "on_period": false,
    "notes": null,
    "code": "MA",
    "triggers": [{ "id": 3, "name": "Stress" }],
    "medications": [
      { "id": 5, "medication_id": 2, "name": "Ibuprofen", "dose": "400 mg", "taken_time": "08:45", "effect": "partial" }
    ],
    "created_at": "2026-02-10T09:00:00.000Z",
    "updated_at": "2026-02-10T09:00:00.000Z"
  }
}
```

`code` is a compact label: `M` migraine, `H` headache, `A` aura alone, `MA`/`HA` pain preceded by aura.
`effect` is one of `none`, `partial`, `good`. Times are `HH:MM`.

### List Episodes

```
GET /api/v1/episodes
```

**Query parameters:** `page`, `year` (e.g. `2026`), `month` (e.g. `2026-02`). Newest first.

**Response:** `200 OK` with `data` (episodes), `meta` (pagination) and `links`.

### Get Episode

```
GET /api/v1/episodes/:id
```

### Create Episode

```
POST /api/v1/episodes
```

**Body** (JSON, either at the top level or wrapped in `episode`):

| Field | Type | Notes |
|-------|------|-------|
| `occurred_on` | date | required, `YYYY-MM-DD` |
| `pain_kind` | string | `migraine`, `headache` or omitted |
| `aura` | boolean | default `false` |
| `intensity` | integer | 1-10, required when `pain_kind` is set |
| `started_time` | string | `HH:MM` |
| `duration_minutes` | integer | 1 to 4320 |
| `on_period` | boolean | |
| `notes` | string | |
| `trigger_ids` | integer[] | ids of your own triggers |
| `medication_intakes_attributes` | object[] | `{ "medication_id", "dose", "taken_time", "effect" }`; to edit/remove on update add `id` and `_destroy` |

```json
{
  "occurred_on": "2026-02-10", "aura": true, "pain_kind": "migraine", "intensity": 7,
  "trigger_ids": [3],
  "medication_intakes_attributes": [{ "medication_id": 2, "dose": "400 mg" }]
}
```

**Response:** `201 Created` with the episode. `422` when neither aura nor pain is given, the intensity is
out of range, or a medication/trigger belongs to someone else. The write is atomic: on error nothing is saved.

### Update Episode

```
PATCH /api/v1/episodes/:id
```

Same fields as create. `trigger_ids` replaces the whole set of triggers.

### Delete Episode

```
DELETE /api/v1/episodes/:id
```

**Response:** `204 No Content` (intakes and trigger links are removed with the episode).

### Calendar View

```
GET /api/v1/episodes/calendar?month=2026-02
```

Returns the month's episodes and `meta.episodes_by_day` (`{ "10": [12, 13] }`, day to episode ids).
`400` for a malformed month.

### Yearly View

```
GET /api/v1/episodes/yearly?year=2026
```

Returns the year's episodes and `meta.months` (`month`, `month_name`, `count`, `episode_ids`).

---

## Medications Endpoints

Medication resource attributes: `name`, `kind` (`acute`, `preventive`, `other`), `default_dose`,
`archived`, `episodes_count`, `created_at`, `updated_at`.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/v1/medications` | active medications; add `?include_archived=true` for all |
| GET | `/api/v1/medications/:id` | |
| POST | `/api/v1/medications` | `{ "name", "kind", "default_dose" }`; name unique per user, ignoring case |
| PATCH | `/api/v1/medications/:id` | same fields |
| DELETE | `/api/v1/medications/:id` | **archives** the medication when it was used in an episode (history is kept), deletes it otherwise. `204` either way |

---

## Triggers Endpoints

Trigger resource attributes: `name`, `episodes_count`, `created_at`, `updated_at`. New accounts start
with a default list (stress, lack of sleep, ...) in the language of the sign-up page.

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/v1/triggers` | alphabetical |
| POST | `/api/v1/triggers` | `{ "name" }`, unique per user ignoring case |
| PATCH | `/api/v1/triggers/:id` | |
| DELETE | `/api/v1/triggers/:id` | removed from past episodes too; `204` |

---

## Statistics Endpoints

All endpoints require authorization and only count the caller's data.

| Path | Response attributes |
|------|---------------------|
| `GET /api/v1/stats` | `total_episodes`, `with_medication`, `without_medication`, `average_intensity`, `aura_count`, `on_period_count` |
| `GET /api/v1/stats/monthly?months=12` | `months: [{ month, month_name, count }]`, the current month plus the previous ones (1-24) |
| `GET /api/v1/stats/by_day_of_week` | `days: [{ day, day_number, count }]` (Sunday = 0), `total` |
| `GET /api/v1/stats/by_medication` | `medications: [{ name, count }]` (number of intakes, plus `None` for episodes without medication), `total` |
| `GET /api/v1/stats/by_pain_kind` | `kinds: [{ kind, count }]` for `migraine`, `headache`, `aura_only`; `with_aura`, `total` |
| `GET /api/v1/stats/by_intensity` | `intensities: [{ intensity, count }]` for 1-10, `total`, `average` (episodes with pain only) |
| `GET /api/v1/stats/by_trigger` | `triggers: [{ name, count }]` sorted by frequency, `total_episodes` |

---

## Data Management Endpoints

### Export Data

```
GET /api/v1/data/export
```

**Response:** `200 OK`. `data.attributes` is the backup (format version 2):

```json
{
  "format_version": 2,
  "exported_at": "2026-02-10T10:00:00Z",
  "user_email": "user@example.com",
  "medications": [{ "name": "Ibuprofen", "kind": "acute", "default_dose": "400 mg", "archived": false, "created_at": "..." }],
  "triggers": [{ "name": "Stress" }],
  "episodes": [{
    "occurred_on": "2026-02-10", "started_time": "08:30", "duration_minutes": 240,
    "aura": true, "pain_kind": "migraine", "intensity": 7, "on_period": false, "notes": null,
    "triggers": ["Stress"],
    "medications": [{ "name": "Ibuprofen", "dose": "400 mg", "taken_time": "08:45", "effect": "partial" }],
    "created_at": "..."
  }]
}
```

`meta` holds `medications_count`, `triggers_count`, `episodes_count`.

### Import Data

```
POST /api/v1/data/import
```

**Body:** `{ "data": <backup as above> }` (up to 2 MB). Only `episodes` is required.

Rules:
- All or nothing: one invalid row rejects the whole import (`422`), and the error names the row
  (`"Episode #2: invalid or missing date (expected YYYY-MM-DD)"`).
- Dates are strict `YYYY-MM-DD`, times `HH:MM`.
- Medications and triggers are matched by name ignoring case; unknown ones are created. Existing
  (even archived) medications are reused and never un-archived.
- Episodes identical to an existing one (date, time, pain, aura, intensity, duration) are skipped, so
  importing your own export twice changes nothing. Two different episodes the same day are kept.
- `user_email`, when present, must match your account.
- Limits: 20,000 episodes, 500 medications, 200 triggers. `413` above 2 MB.

**Response:** `200 OK`
```json
{
  "data": { "type": "import_result", "id": "...", "attributes": {
    "imported_at": "...", "medications_imported": 1, "triggers_imported": 1, "episodes_imported": 2 } },
  "meta": { "message": "Successfully imported 1 medications, 1 triggers and 2 episodes." }
}
```

---

## SDK Examples

### JavaScript/TypeScript

```typescript
const API_BASE = 'https://your-app.com/api/v1';

class MigraineTrackerAPI {
  private token: string | null = null;

  async login(email: string, password: string): Promise<void> {
    const response = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    
    this.token = response.headers.get('Authorization')?.replace('Bearer ', '') || null;
  }

  async getEpisodes(page = 1): Promise<any> {
    const response = await fetch(`${API_BASE}/episodes?page=${page}`, {
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Accept': 'application/vnd.api+json'
      }
    });
    return response.json();
  }

  async createEpisode(data: {
    occurred_on: string;
    pain_kind?: 'migraine' | 'headache';
    aura?: boolean;
    intensity?: number;
    trigger_ids?: number[];
    medication_intakes_attributes?: { medication_id: number; dose?: string }[];
  }): Promise<any> {
    const response = await fetch(`${API_BASE}/episodes`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.api+json'
      },
      body: JSON.stringify(data)
    });
    return response.json();
  }
}
```

### Swift (iOS)

```swift
import Foundation

struct MigraineTrackerAPI {
    let baseURL = "https://your-app.com/api/v1"
    var token: String?
    
    mutating func login(email: String, password: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/auth/login")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           let auth = httpResponse.value(forHTTPHeaderField: "Authorization") {
            token = auth.replacingOccurrences(of: "Bearer ", with: "")
        }
    }
    
    func getEpisodes() async throws -> Data {
        var request = URLRequest(url: URL(string: "\(baseURL)/episodes")!)
        request.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}
```

---

## Changelog

### v1.0.0 (February 2026)
- Initial API release
- JWT authentication with 1-hour token expiration
- Full CRUD for episodes and medications
- Statistics endpoints
- Data export/import functionality
- User profile management including account deletion
- Rate limiting (100 req/min authenticated, 10 req/min for auth endpoints)

### v2.0.0 (October 2026)
Breaking changes (no production data existed, so there is no migration path):
- `migraines` became `episodes` (`/api/v1/migraines` is gone). The `nature` codes `M/H/A/MA/MH` are
  replaced by `pain_kind` (`migraine`/`headache`/none) plus an independent `aura` flag; several episodes
  per day are allowed; optional `started_time`, `duration_minutes`, `notes`.
- One medication per migraine became several `medication_intakes` per episode with dose, time and effect.
- Medications gained `kind`, `default_dose` and archiving (`DELETE` archives used medications).
- New `/api/v1/triggers` and `trigger_ids` on episodes; `GET /stats/by_trigger`.
- `GET /stats/by_nature` became `GET /stats/by_pain_kind`; `total_migraines` became `total_episodes`;
  intensity is 1-10 and only present with pain.
- Backup format version 2 (export and import); imports are all-or-nothing with row-numbered errors.
- User resources expose `episodes_count` (was `migraines_count`) and `track_cycle` (read-only for now).
