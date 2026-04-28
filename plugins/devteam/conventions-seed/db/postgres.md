# Postgres Conventions

## Stack overview

PostgreSQL 14+. Migrations in plain SQL files (versioned), or via tools like Knex/Prisma/Drizzle/Atlas. Connection pooling via PgBouncer or framework-native pool.

## Conventions

- **Snake_case** for table and column names.
- **Plural table names** (`users`, not `user`).
- **`id` BIGSERIAL or UUID primary keys** — pick one per project, stick with it.
- **`created_at`, `updated_at` timestamps** with `DEFAULT now()` and trigger to update.
- **Foreign keys explicit** with `ON DELETE` behavior chosen per relationship.
- **Indexes named `<table>_<columns>_idx`** — predictable and greppable.
- **Migrations are forward-only**; rollbacks are new migrations.

## Anti-patterns

- **Don't use `SELECT *` in application code** — list columns explicitly.
- **Don't index everything** — indexes cost on writes; only add when query plans show seq scans on real data.
- **Don't use `text` everywhere** when constrained types fit (`varchar(N)`, `int`, `boolean`, `timestamp`).
- **Don't put business logic in triggers** unless strong reason — debugging gets hard.
- **Don't run migrations without a backup** — even forward-only.

## Test patterns

- Use a separate test database; reset between tests via transaction rollback or schema reset.
- Test migrations: apply, verify schema, apply next, verify, repeat.
- For complex queries: snapshot the query plan and check for regressions.

## Common pitfalls

- N+1 queries — load related rows eagerly with JOIN or use a dataloader.
- Implicit casts in WHERE clauses prevent index use.
- Long-running transactions block VACUUM and bloat the DB.
- Migrations with `ALTER TABLE` on huge tables can lock for long periods — use zero-downtime patterns.

## References

- [Postgres docs](https://www.postgresql.org/docs/current/)
- [Use The Index, Luke!](https://use-the-index-luke.com/)
