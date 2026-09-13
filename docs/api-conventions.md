# api-conventions.md

**Version:** 1.1 · **Applies to:** All APIs exposed by every subsystem

> This document standardises API conventions across all subsystems so automated checks can verify compliance
> and every AI Engineer produces APIs in a consistent shape.
> Every rule here is enforced in `conformance/` at level L2.

---

## ⚡ Quick Reference (Start here — the full picture at a glance)

| Topic | Rule |
|---|---|
| **URL** | `/api/v1/<noun-plural-kebab>` e.g. `/api/v1/borrow-records` |
| **Create** | `POST` → `201` |
| **List** | `GET` → `200` + `data[]` + `meta{}` |
| **Single item** | `GET /:id` → `200` + `data{}` |
| **Update** | `PATCH /:id` → `200` + `data{}` |
| **Delete** | `DELETE /:id` → `200` + `{ id, deleted: true }` (**never `204`**) |
| **JSON fields** | Always `camelCase` (`studentCode`, `createdAt`) |
| **Timestamps** | ISO 8601 UTC ending in `Z` e.g. `"2026-09-11T09:30:00.000Z"` |
| **Every response** | Wrapped in `{ success, data }` — no exceptions |
| **Error** | `{ success: false, error: { code, message, details } }` |
| **Pagination** | `?page=1&limit=20` · max `limit=100` |
| **Public endpoints** | `GET /api/health` and `GET /auth/callback` only |
| **Auth header** | `Authorization: Bearer <token>` |
| **No token** | `401 UNAUTHORIZED` |
| **Wrong permission** | `403 FORBIDDEN` |

---

## 1. URL Structure

```text
https://<subsystem-domain>/api/v1/<resource>[/<id>][/<sub-resource>]
```

### URL Rules

| Rule | ✅ Correct | ❌ Wrong |
|---|---|---|
| Plural noun + kebab-case | `/api/v1/borrow-records` | `/api/v1/borrowRecord`, `/api/v1/getBorrowRecord` |
| No verbs in path | `POST /api/v1/enrollments` | `POST /api/v1/createEnrollment` |
| Special actions → sub-resource of id | `POST /api/v1/borrow-records/:id/return` | `POST /api/v1/returnBorrowRecord` |
| Max 1 level of nesting | `/api/v1/students/:id/enrollments` | `/api/v1/students/:id/courses/:id/grades` |
| No trailing slash | `/api/v1/students` | `/api/v1/students/` |
| Path params must be UUID v4 | `/api/v1/students/550e8400-...` | `/api/v1/students/12345` → must respond `400` |
| Query params in camelCase | `?studentId=&status=&page=` | `?student_id=&Status=` |

### Endpoints outside `/api/v1/` (exactly 2 paths)

| Path | Reason |
|---|---|
| `GET /api/health` | Used for monitoring · not version-bound · public |
| `GET /auth/callback` | Must match the `callback_url` registered with Core Hub · public |

### Versioning

- **Breaking change** (removing/renaming a field, changing status semantics) → release as `/api/v2` and keep `v1` alive for at least 1 semester
- **Non-breaking change** (adding a field or endpoint) → ship directly, no version bump needed

---

## 2. HTTP Methods and Status Codes

| Method | Purpose | Success status | Notes |
|---|---|---|---|
| `GET /api/v1/<res>` | List | `200` | Must have a deterministic sort order |
| `GET /api/v1/<res>/:id` | Single item | `200` | Not found → `404` |
| `POST /api/v1/<res>` | Create | **`201`** | Business rule conflict → `409` |
| `PATCH /api/v1/<res>/:id` | Partial update | `200` | Send only fields you want to change |
| `DELETE /api/v1/<res>/:id` | Delete | `200` | **Never `204`** — envelope is always required |
| `PUT` | Full replacement | `200` | **Avoid** — prefer `PATCH` |

---

## 3. Response Format — Success

**Every response must be wrapped in the envelope** — regardless of whether it's GET, POST, or DELETE.

### Single object

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "studentCode": "64010001",
    "fullName": "John Doe",
    "createdAt": "2026-09-11T09:30:00.000Z"
  }
}
```

### Collection (must always include `meta`)

```json
{
  "success": true,
  "data": [
    { "id": "550e8400-...", "studentCode": "64010001" },
    { "id": "661f9511-...", "studentCode": "64010002" }
  ],
  "meta": {
    "total": 42,
    "page": 1,
    "limit": 20,
    "totalPages": 3
  }
}
```

### Successful DELETE

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "deleted": true
  }
}
```

> Allowed top-level keys: `success`, `data`, `meta` only.

---

## 4. Response Format — Error

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      "quantity must be greater than 0",
      "returnDate must be a valid ISO 8601 date"
    ]
  }
}
```

### Error Codes (closed list — use only these)

`error.code` must be SCREAMING_SNAKE_CASE and must be one of the following values.
(Conformance reads the canonical list from [`../contracts/error-codes.json`](../contracts/error-codes.json))

| code | HTTP | When to use | Example |
|---|---|---|---|
| `BAD_REQUEST` | 400 | Malformed request in general | Wrong method, bad path |
| `VALIDATION_ERROR` | **400** | body/query fails validation | Missing field, wrong type, value out of range |
| `UNAUTHORIZED` | 401 | Caller identity unknown | No token / expired token |
| `FORBIDDEN` | 403 | Identity known but insufficient permission | Student calling an admin endpoint |
| `NOT_FOUND` | 404 | Resource does not exist | `:id` not in database |
| `CONFLICT` | 409 | Business rule violation | Borrowing an item already on loan |
| `INTERNAL_ERROR` | 500 | Unexpected server error | Unhandled exception |

> Use `VALIDATION_ERROR` with **400**, not 422 — this matches NestJS `ValidationPipe` defaults so no custom exception filter is needed.

**Never leak the following in a response:**
- Stack traces
- Server file paths or filenames
- Raw ORM or SQL error messages (e.g. `duplicate key value violates unique constraint`)

---

## 5. Pagination

```text
GET /api/v1/students?page=1&limit=20
```

- Defaults: `page=1`, `limit=20`
- Maximum: `limit=100`
- Non-numeric `limit` or value out of range → `400 VALIDATION_ERROR`
- **Empty collection** → return `data: []` + `meta.total: 0` (never `null`, never `404`)

```json
{
  "success": true,
  "data": [],
  "meta": { "total": 0, "page": 1, "limit": 20, "totalPages": 0 }
}
```

---

## 6. Field Naming

| Layer | Format | Examples |
|---|---|---|
| JSON output from API | **camelCase** | `studentCode`, `createdAt`, `coreUserId` |
| OAuth fields | `snake_case` (international standard) | `access_token`, `token_type`, `expires_in` |
| Database columns | **snake_case** | `student_code`, `created_at` |

- Timestamps must use **ISO 8601 UTC** ending in `Z` — `"2026-09-11T09:30:00.000Z"`
- Every id must be **UUID v4**
- Field names that match shared variables must exactly follow `data-dictionary.md` — no renaming

---

## 7. Security — Authentication

### 7.1 Token format

Every request to `/api/v1/` must include a JWT token issued by Core Hub in the `Authorization` header:

```http
Authorization: Bearer <jwt-token>
```

No token, wrong format, or expired token → respond `401 UNAUTHORIZED` immediately. Do not process the request.

### 7.2 How to validate the token (NestJS)

Use the shared `JwtAuthGuard` from the Core Hub SDK — do not write your own JWT validation logic.

```ts
// Apply globally in main module (recommended)
// app.module.ts

import { APP_GUARD } from "@nestjs/core";
import { JwtAuthGuard } from "@csmju/core-sdk";

@Module({
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard, // protects every route by default
    },
  ],
})
export class AppModule {}
```

To make a specific route public, use the `@Public()` decorator:

```ts
import { Public } from "@csmju/core-sdk";

@Public()
@Get("/api/health")
health() {
  return { success: true, data: { status: "ok", service: "csmju-equipment" } };
}
```

### 7.3 Reading the caller's identity

After validation, the guard injects the decoded token into `request.user`:

```ts
import { CurrentUser, JwtPayload } from "@csmju/core-sdk";

@Get("/api/v1/students")
findAll(@CurrentUser() user: JwtPayload) {
  console.log(user.sub);      // Core Hub user UUID
  console.log(user.role);     // e.g. "student", "staff", "admin"
  console.log(user.studentId); // subsystem-specific id (if present)
}
```

### 7.4 Role-based access (FORBIDDEN vs UNAUTHORIZED)

| Situation | Response |
|---|---|
| No token / invalid token / expired | `401 UNAUTHORIZED` — caller identity unknown |
| Valid token but role not allowed | `403 FORBIDDEN` — identity known, permission denied |

```ts
import { Roles, RolesGuard } from "@csmju/core-sdk";

@Roles("admin", "staff")      // students will get 403
@UseGuards(RolesGuard)
@Delete("/api/v1/students/:id")
remove(@Param("id") id: string) { … }
```

### 7.5 Error responses

**401 — No token or invalid token:**

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Missing or invalid token"
  }
}
```

**403 — Valid token but insufficient role:**

```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN",
    "message": "You do not have permission to perform this action"
  }
}
```

### 7.6 Public endpoints declaration

Endpoints accessible without a token must be declared in `subsystem.yaml`:

```yaml
public_endpoints:
  - GET /api/health
  - GET /auth/callback
```

> If not declared, conformance will fail — the system assumes the endpoint is protected.

---

## 8. Health Check (required for every subsystem)

```http
GET /api/health
```

**Expected response:**

```json
{
  "success": true,
  "data": {
    "status": "ok",
    "service": "csmju-equipment"
  }
}
```

- `data.service` must exactly match `name` in `subsystem.yaml`
- `data.service` must exactly match the `name` registered with Core Hub
- This endpoint is public — no token required

> Core Hub itself uses `/api/v1/health` (versioned), which is a Core Hub–only exception. All other subsystems use `/api/health`.

---

## 9. Anti-patterns — What Not to Do

Common mistakes that will cause an immediate PR rejection.

### ❌ Verb in URL

```text
POST /api/v1/createEnrollment     ← wrong
POST /api/v1/enrollments          ← correct
```

### ❌ Response without envelope

```json
// wrong — raw data with no wrapper
{ "id": "abc", "name": "Test" }

// correct
{ "success": true, "data": { "id": "abc", "name": "Test" } }
```

### ❌ DELETE returning 204

```text
DELETE /api/v1/students/:id → 204 No Content   ← wrong
DELETE /api/v1/students/:id → 200 + { id, deleted: true }   ← correct
```

### ❌ Empty collection returning 404

```text
GET /api/v1/students?status=inactive → 404   ← wrong (query is valid, data just doesn't exist)
GET /api/v1/students?status=inactive → 200 + data:[] + meta   ← correct
```

### ❌ Leaking raw error messages

```json
// wrong — exposes internal structure
{
  "success": false,
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "duplicate key value violates unique constraint \"students_student_code_key\""
  }
}

// correct
{
  "success": false,
  "error": {
    "code": "CONFLICT",
    "message": "Student code already exists"
  }
}
```

### ❌ Writing custom JWT validation instead of using the SDK

```ts
// wrong — never do this
const token = request.headers.authorization?.split(" ")[1];
const decoded = jwt.verify(token, process.env.JWT_SECRET);

// correct — use the shared guard from Core Hub SDK
// JwtAuthGuard applied globally in AppModule handles this automatically
```

### ❌ Returning 403 when the token is missing

```json
// wrong — no token means identity is unknown → 401
{ "success": false, "error": { "code": "FORBIDDEN", "message": "Access denied" } }

// correct — no token → 401, wrong role → 403
{ "success": false, "error": { "code": "UNAUTHORIZED", "message": "Missing or invalid token" } }
```

### ❌ snake_case JSON fields

```json
// wrong
{ "student_code": "64010001", "created_at": "2026-09-11T09:30:00.000Z" }

// correct
{ "studentCode": "64010001", "createdAt": "2026-09-11T09:30:00.000Z" }
```

---

## 10. Not Yet in the Current Architecture

| Topic | Status |
|---|---|
| API Gateway / rate limit headers (`X-RateLimit-*`) | ❌ Not available — do not design assuming these exist |
| Cross-subsystem calls (service-to-service) | ❌ No contract yet — must go through the Change Process first |

---

## 11. PR Merge Checklist

> Run through this before every push — conformance checks all of these automatically.

- [ ] URL uses plural noun + kebab-case + lives under `/api/v1/`
- [ ] No verbs in the URL path
- [ ] `POST` returns `201` · `DELETE` returns `200` + `{ id, deleted: true }` (not `204`)
- [ ] Every response is wrapped in `{ success, data[, meta] }` or `{ success: false, error }`
- [ ] `error.code` is from the closed list only · `VALIDATION_ERROR` uses HTTP 400
- [ ] Collections include `meta { total, page, limit, totalPages }` and support `?page=&limit=`
- [ ] Empty collections return `data: []` + `meta.total: 0`, not `404`
- [ ] JSON response fields are camelCase · DB columns are snake_case
- [ ] Timestamps are ISO 8601 UTC ending in `Z`
- [ ] Every id is UUID v4 · non-UUID path params respond `400`
- [ ] No stack trace / SQL error / file path leaking in any response
- [ ] `JwtAuthGuard` applied globally in `AppModule` — no route under `/api/v1/` is accidentally public
- [ ] Public endpoints use `@Public()` decorator and are declared in `subsystem.yaml`
- [ ] No token → `401 UNAUTHORIZED` · wrong role → `403 FORBIDDEN` (not swapped)
- [ ] No custom JWT parsing — uses `@csmju/core-sdk` only
- [ ] `GET /api/health` exists · `data.service` matches the system name in `subsystem.yaml`
- [ ] `public_endpoints` declared in `subsystem.yaml` completely
- [ ] `node standards/conformance/run.js` passes at L2 or above
