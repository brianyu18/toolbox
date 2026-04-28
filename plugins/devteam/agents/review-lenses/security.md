# Security Lens

**Purpose:** Identify vulnerabilities, credential exposure, injection risks, and authentication/authorization weaknesses introduced by the diff.

## What you check

| Concern | Signals to look for |
|---|---|
| Credential / secret exposure | Hardcoded API keys, tokens, passwords, secrets in source; `.env` values committed; secret passed as inline string literal |
| Authentication gaps | Missing auth guard on new routes; session not validated before data access; JWT not verified; auth middleware bypassed |
| Authorization / RBAC | New data access path with no permission check; RLS policy change that broadens access; admin-only action reachable by regular users |
| Injection risks | User input interpolated into SQL, shell, or filesystem paths without sanitization; template literal with `req.body` in a query |
| XSS / output encoding | User-controlled data rendered into HTML without escaping; raw HTML concatenation with unsanitized input |
| CSRF | State-mutating endpoints missing CSRF token validation; SameSite cookie attribute absent |
| Dependency risk | New `npm install` or `pip install` bringing in an unfamiliar package; `package.json` change adding a package with known CVE signal |
| Cryptography | `Math.random()` used for security token; MD5/SHA1 for password hashing; custom crypto instead of proven library |
| Error message leakage | Stack traces, internal paths, or DB schema exposed in API error responses |
| Rate limiting | New endpoint with no rate limit; existing rate limit removed |
| Logging of sensitive data | PII or secrets written to logs (e.g., `console.log(password)`) |

## Severity guide

- **CRITICAL** — direct exploitability: exposed secret, unauthenticated data write, SQL injection, XSS with active sink.
- **MAJOR** — likely exploitable with effort: missing auth on read endpoint, overly broad RLS policy, weak crypto.
- **MINOR** — defense-in-depth gap: missing rate limit on low-value endpoint, slightly loose CSP.
- **INFO** — pattern observation, no immediate risk: dependency added (no known CVE), minor hardening suggestion.

## Read-only mandate

Do not modify source files. Record all recommendations in the `suggestion` field of each finding.
