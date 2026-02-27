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
      "migraines_count": 0,
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
      "migraines_count": 5,
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
      "migraines_count": 5,
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

## Migraines Endpoints

### List Migraines

Get a paginated list of the user's migraines.

```
GET /api/v1/migraines
```

**Headers:** Authorization required

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `page` | integer | Page number (default: 1) |
| `year` | string | Filter by year (e.g., "2026") |
| `month` | string | Filter by month (e.g., "2026-02") |

**Response:** `200 OK`
```json
{
  "data": [
    {
      "id": "1",
      "type": "migraine",
      "attributes": {
        "occurred_on": "2026-02-15",
        "nature": "M",
        "intensity": 5,
        "on_period": false,
        "nature_label": "Migraine (M)",
        "created_at": "2026-02-15T10:00:00Z",
        "updated_at": "2026-02-15T10:00:00Z"
      },
      "relationships": {
        "medication": {
          "data": {
            "id": "1",
            "type": "medication"
          }
        }
      }
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 45,
    "per_page": 20
  },
  "links": {
    "self": "/api/v1/migraines?page=1",
    "first": "/api/v1/migraines?page=1",
    "last": "/api/v1/migraines?page=3",
    "next": "/api/v1/migraines?page=2"
  }
}
```

---

### Get Migraine

```
GET /api/v1/migraines/:id
```

**Headers:** Authorization required

**Response:** `200 OK`

---

### Create Migraine

```
POST /api/v1/migraines
```

**Headers:** Authorization required

**Request Body:**
```json
{
  "occurred_on": "2026-02-17",
  "nature": "M",
  "intensity": 5,
  "on_period": false,
  "medication_id": 1
}
```

**Nature Values:**
| Value | Description |
|-------|-------------|
| `M` | Migraine |
| `H` | Headache |
| `A` | Migraine with aura |
| `MA` | Migraine with aura |
| `MH` | Migraine with headache |

**Intensity:** Integer from 0-10

**Response:** `201 Created`

---

### Update Migraine

```
PATCH /api/v1/migraines/:id
```

**Headers:** Authorization required

**Request Body:** (any subset of create fields)
```json
{
  "intensity": 7,
  "on_period": true
}
```

**Response:** `200 OK`

---

### Delete Migraine

```
DELETE /api/v1/migraines/:id
```

**Headers:** Authorization required

**Response:** `204 No Content`

---

### Calendar View

Get migraines for a specific month (for calendar display).

```
GET /api/v1/migraines/calendar
```

**Headers:** Authorization required

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `month` | string | Month in YYYY-MM format (default: current month) |

**Response:** `200 OK`
```json
{
  "data": [...],
  "meta": {
    "month": 2,
    "year": 2026,
    "month_name": "February",
    "days_in_month": 28,
    "migraines_by_day": {
      "5": 123,
      "15": 124
    }
  }
}
```

---

### Yearly View

Get all migraines for a year with monthly breakdown.

```
GET /api/v1/migraines/yearly
```

**Headers:** Authorization required

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `year` | integer | Year (default: current year) |

**Response:** `200 OK`
```json
{
  "data": [...],
  "meta": {
    "year": 2026,
    "total_count": 45,
    "months": [
      {
        "month": "2026-01",
        "month_name": "January",
        "count": 3,
        "migraine_ids": [1, 2, 3]
      }
    ]
  }
}
```

---

## Medications Endpoints

### List Medications

```
GET /api/v1/medications
```

**Headers:** Authorization required

**Response:** `200 OK`
```json
{
  "data": [
    {
      "id": "1",
      "type": "medication",
      "attributes": {
        "name": "Ibuprofen",
        "created_at": "2026-01-01T00:00:00Z",
        "updated_at": "2026-01-01T00:00:00Z",
        "migraines_count": 10
      }
    }
  ]
}
```

---

### Get Medication

```
GET /api/v1/medications/:id
```

**Headers:** Authorization required

**Response:** `200 OK`

---

### Create Medication

```
POST /api/v1/medications
```

**Headers:** Authorization required

**Request Body:**
```json
{
  "name": "Sumatriptan"
}
```

**Response:** `201 Created`

---

### Update Medication

```
PATCH /api/v1/medications/:id
```

**Headers:** Authorization required

**Request Body:**
```json
{
  "name": "Updated Name"
}
```

**Response:** `200 OK`

---

### Delete Medication

```
DELETE /api/v1/medications/:id
```

**Headers:** Authorization required

**Response:** `204 No Content`

---

## Statistics Endpoints

### Overall Stats

```
GET /api/v1/stats
```

**Headers:** Authorization required

**Response:** `200 OK`
```json
{
  "data": {
    "id": "1-stats",
    "type": "stats",
    "attributes": {
      "total_migraines": 45,
      "with_medication": 30,
      "without_medication": 15,
      "average_intensity": 4.5
    }
  }
}
```

---

### Monthly Stats

```
GET /api/v1/stats/monthly
```

**Headers:** Authorization required

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `months` | integer | Number of months to include (default: 12) |

**Response:** `200 OK`
```json
{
  "data": {
    "id": "1-monthly",
    "type": "monthly_stats",
    "attributes": {
      "period_start": "2025-03-01",
      "period_end": "2026-02-28",
      "months": [
        {
          "month": "2026-02",
          "month_name": "February",
          "year": 2026,
          "count": 5,
          "with_medication": 3,
          "without_medication": 2,
          "average_intensity": 4.2
        }
      ]
    }
  }
}
```

---

### Stats by Day of Week

```
GET /api/v1/stats/by_day_of_week
```

**Headers:** Authorization required

**Response:** `200 OK`
```json
{
  "data": {
    "id": "1-dow",
    "type": "day_of_week_stats",
    "attributes": {
      "days": [
        { "day": "sunday", "day_number": 0, "count": 5 },
        { "day": "monday", "day_number": 1, "count": 8 }
      ],
      "total": 45
    }
  }
}
```

---

### Stats by Medication

```
GET /api/v1/stats/by_medication
```

**Headers:** Authorization required

**Response:** `200 OK`
```json
{
  "data": {
    "id": "1-meds",
    "type": "medication_stats",
    "attributes": {
      "medications": [
        { "name": "Ibuprofen", "count": 15 },
        { "name": "Paracetamol", "count": 10 },
        { "name": "None", "count": 20 }
      ],
      "total": 45
    }
  }
}
```

---

### Stats by Nature

```
GET /api/v1/stats/by_nature
```

**Headers:** Authorization required

**Response:** `200 OK`
```json
{
  "data": {
    "id": "1-nature",
    "type": "nature_stats",
    "attributes": {
      "natures": [
        { "nature": "M", "label": "Migraine (M)", "count": 25 },
        { "nature": "H", "label": "Headache (H)", "count": 15 }
      ],
      "total": 45
    }
  }
}
```

---

### Stats by Intensity

```
GET /api/v1/stats/by_intensity
```

**Headers:** Authorization required

**Response:** `200 OK`
```json
{
  "data": {
    "id": "1-intensity",
    "type": "intensity_stats",
    "attributes": {
      "intensities": [
        { "intensity": 0, "count": 0 },
        { "intensity": 1, "count": 2 },
        { "intensity": 5, "count": 15 }
      ],
      "total": 45,
      "average": 4.5
    }
  }
}
```

---

## Data Management Endpoints

### Export Data

Export all user data (medications and migraines) in JSON format.

```
GET /api/v1/data/export
```

**Headers:** Authorization required

**Response:** `200 OK`
```json
{
  "data": {
    "id": "uuid",
    "type": "export",
    "attributes": {
      "exported_at": "2026-02-17T14:00:00Z",
      "user_email": "user@example.com",
      "medications": [
        {
          "name": "Ibuprofen",
          "created_at": "2026-01-01T00:00:00Z"
        }
      ],
      "migraines": [
        {
          "occurred_on": "2026-02-15",
          "nature": "M",
          "intensity": 5,
          "on_period": false,
          "medication_name": "Ibuprofen",
          "created_at": "2026-02-15T10:00:00Z"
        }
      ]
    }
  },
  "meta": {
    "medications_count": 2,
    "migraines_count": 45
  }
}
```

---

### Import Data

Import medications and migraines from a previously exported JSON file.

```
POST /api/v1/data/import
```

**Headers:** Authorization required

**Request Body:**
```json
{
  "data": {
    "user_email": "user@example.com",
    "medications": [
      { "name": "Imported Med" }
    ],
    "migraines": [
      {
        "occurred_on": "2025-01-15",
        "nature": "M",
        "intensity": 4,
        "on_period": false,
        "medication_name": "Imported Med"
      }
    ]
  }
}
```

**Notes:**
- Duplicate medications (by name) are skipped
- Duplicate migraines (by date) are skipped
- Email must match the authenticated user's email

**Response:** `200 OK`
```json
{
  "data": {
    "id": "uuid",
    "type": "import_result",
    "attributes": {
      "imported_at": "2026-02-17T14:00:00Z",
      "medications_imported": 1,
      "migraines_imported": 1
    }
  },
  "meta": {
    "message": "Successfully imported 1 medications and 1 migraines."
  }
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

  async getMigraines(page = 1): Promise<any> {
    const response = await fetch(`${API_BASE}/migraines?page=${page}`, {
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Accept': 'application/vnd.api+json'
      }
    });
    return response.json();
  }

  async createMigraine(data: {
    occurred_on: string;
    nature: string;
    intensity: number;
    on_period?: boolean;
    medication_id?: number;
  }): Promise<any> {
    const response = await fetch(`${API_BASE}/migraines`, {
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
    
    func getMigraines() async throws -> Data {
        var request = URLRequest(url: URL(string: "\(baseURL)/migraines")!)
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
- Full CRUD for migraines and medications
- Statistics endpoints (overall, monthly, by day, by medication, by nature, by intensity)
- Data export/import functionality
- User profile management including account deletion
- Rate limiting (100 req/min authenticated, 10 req/min for auth endpoints)
