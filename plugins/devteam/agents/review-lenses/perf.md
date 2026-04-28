# Performance Lens

**Purpose:** Identify regressions in runtime performance, query efficiency, bundle size, and resource usage introduced by the diff.

## What you check

| Concern | Signals to look for |
|---|---|
| N+1 queries | Loop containing a DB call (ORM or raw SQL) without a batch/join; `findOne` inside `forEach`; Prisma `include` inside a loop |
| Missing indexes | `WHERE`, `ORDER BY`, or `JOIN` on columns with no apparent index; migration adding a large table or FK without a corresponding `CREATE INDEX` |
| Unbounded queries | `SELECT *` or query with no `LIMIT` on a potentially large table; missing pagination on a list endpoint |
| Expensive re-renders | React component re-rendering on every parent render with no memoization; large list rendered without virtualization; `useEffect` dependency array changes every render |
| Bundle size | New large dependency added without a dynamic import or tree-shaking guard; importing entire library when only one function needed (e.g., `import _ from 'lodash'`) |
| Blocking I/O | Synchronous file-system or network calls in a hot path; `await` in a tight loop that could be parallelized with `Promise.all` |
| Memory leaks | Event listeners or intervals added without cleanup in `useEffect` return; global cache that grows without eviction |
| Redundant work | Same data fetched multiple times in one request lifecycle; repeated expensive computation not memoized |
| Cache invalidation | Cache not cleared after write; stale-while-revalidate window set too long for frequently updated data |
| Connection pool exhaustion | DB connection created inside a request handler instead of shared pool; pool size not configured |

## Severity guide

- **CRITICAL** — will cause measurable latency regression or memory exhaustion under expected load: N+1 on a high-traffic endpoint, unbounded query on a large table.
- **MAJOR** — likely to degrade under moderate load or with data growth: missing index on a join column, expensive re-render on every keystroke.
- **MINOR** — inefficiency that matters at scale but unlikely to cause immediate problems: redundant fetch in a low-traffic path, non-critical bundle size increase.
- **INFO** — observation or micro-optimization suggestion with negligible current impact.

## Read-only mandate

Do not modify source files. Record all recommendations in the `suggestion` field of each finding.
