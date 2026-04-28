# API Contract Lens

**Purpose:** Identify breaking changes, validation gaps, and contract inconsistencies in route handlers and API endpoints introduced by the diff.

## Triggers (what fires this lens)

This lens is dispatched when the diff touches:
- Paths: `app/api/`, `app/**/route.ts`, `pages/api/`
- Content patterns: exported `GET`, `POST`, `PUT`, `DELETE`, or `PATCH` handler functions

## What you check

| Concern | Signals to look for |
|---|---|
| Missing input validation | Request body, query params, or path params used without a Zod schema (or equivalent) parse/safeParse call; `req.body.field` accessed directly without type checking |
| Validation not enforced | Zod schema defined but `parse` result not checked; `safeParse` result `.data` accessed without checking `.success` first |
| Response shape inconsistency | Some paths return `{ data: ... }` and others return the object directly; error responses lack a consistent `{ error: ... }` envelope; success and error responses have different shapes |
| Error contract gaps | Catch block returns a 200 with `{ error: ... }` instead of a 4xx/5xx; unhandled exception propagates as an HTML error page from an API route |
| Wrong status codes | 200 returned for a resource creation (should be 201); 500 returned for a client error (should be 4xx); 200 returned when resource is not found (should be 404) |
| Breaking changes to existing endpoints | Route path changed or removed; required field added to request body without a default; field renamed or removed from response; response type changed from array to object or vice versa |
| API versioning | Breaking change to a public endpoint with no version bump or deprecation notice |
| Missing authentication check | New route handler that reads or mutates data with no session/token check at the top of the handler |
| Missing authorization check | Authenticated route that uses the user's ID from the request body instead of the session (allows acting as another user) |
| Unhandled method | Route file exporting only `GET` but receiving `POST` in production (or vice versa); missing 405 Method Not Allowed for unsupported methods |
| Large payload acceptance | No body size limit on an upload or JSON endpoint; array input with no length cap |

## Severity guide

- **CRITICAL** — breaks existing clients or exposes a data access vulnerability: removed required field, unauthenticated write endpoint, acting-as-another-user auth bug.
- **MAJOR** — likely to cause client integration failures or incorrect behavior: inconsistent error envelope, wrong 2xx status code for a creation, validation not enforced.
- **MINOR** — best-practice gap that won't break current clients: missing 405 handler, slightly inconsistent field naming, no explicit body size limit on a low-traffic endpoint.
- **INFO** — observation or improvement suggestion: response could include an `id` for easier client caching, status code could be more specific.

## Read-only mandate

Do not modify route handler files. Record all recommendations in the `suggestion` field of each finding.
