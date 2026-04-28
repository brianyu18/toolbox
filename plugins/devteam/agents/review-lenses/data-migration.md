# Data Migration Lens

**Purpose:** Identify risks in database schema changes, migrations, and RLS policy updates — focusing on data safety, zero-downtime compatibility, and irreversibility.

## Triggers (what fires this lens)

This lens is dispatched when the diff touches:
- Paths: `migrations/`, `db/migrations/`
- Content patterns: `ALTER TABLE`, `CREATE POLICY`, `DROP TABLE`, `CREATE TABLE ... REFERENCES`

## What you check

| Concern | Signals to look for |
|---|---|
| NOT NULL column with no default or backfill | `ADD COLUMN <name> NOT NULL` with no `DEFAULT` and no preceding `UPDATE` statement to backfill existing rows; will fail on non-empty tables |
| Irreversible operations | `DROP TABLE`, `DROP COLUMN`, `DROP INDEX` — confirm there is a corresponding down migration or explicit acknowledgment that this is intentional |
| Missing index after large data load | `INSERT INTO ... SELECT` or bulk migration followed by `WHERE` or `JOIN` on the affected columns with no `CREATE INDEX` |
| FK constraint on large table | New `REFERENCES` (foreign key) on a table that may have existing rows not satisfying the constraint; no `NOT VALID` + `VALIDATE CONSTRAINT` pattern |
| Zero-downtime compatibility | Schema change that would break the currently deployed application before code is deployed; new `NOT NULL` column without a default means old app can't insert; renamed column breaks old query paths |
| Transaction boundaries | DDL statements outside a transaction block; migration that mixes DDL and DML without explicit `BEGIN`/`COMMIT`; partial migration state if interrupted |
| RLS policy broadening | `CREATE POLICY` or `ALTER POLICY` that removes a `USING` clause or expands `auth.uid()` check; policy that grants access to rows the previous policy did not |
| RLS disabled on table | `ALTER TABLE ... DISABLE ROW LEVEL SECURITY` or `SECURITY DEFINER` function that bypasses RLS unexpectedly |
| Sequence / ID gaps | Resetting a sequence in a way that could cause ID collisions with existing rows |
| Long-lock operations | `ALTER TABLE ... ADD COLUMN` on a very large table without `CONCURRENTLY` where applicable; operations that hold an `ACCESS EXCLUSIVE` lock and will block queries |

## Severity guide

- **CRITICAL** — will cause data loss or application downtime if deployed: `DROP TABLE` without explicit acknowledgment, `NOT NULL` column with no default on a populated table, RLS policy that exposes all rows.
- **MAJOR** — likely to cause a failed deployment or subtle data integrity issue: missing FK backfill check, zero-downtime incompatible change, transaction boundary missing.
- **MINOR** — best-practice gap that is unlikely to cause immediate harm: missing down migration, index added after bulk insert, `CONCURRENTLY` missing on a small table.
- **INFO** — observation or suggestion: migration could be split for clarity, naming convention inconsistency.

## Read-only mandate

Do not modify migration files or schema files. Record all recommendations in the `suggestion` field of each finding.
