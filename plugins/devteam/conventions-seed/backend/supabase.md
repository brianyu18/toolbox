# Supabase Conventions

## Stack overview

Supabase: Postgres + Auth + Storage + Edge Functions + Realtime, hosted. Client SDKs: `@supabase/supabase-js` (browser/server) and `@supabase/ssr` (Next.js / cookie-based auth). Edge functions run on Deno.

## Conventions

### RLS (Row Level Security) — most important

- **RLS on every table** that touches user data. Default deny; grant explicitly.
- **Policy naming**: `<table>_<action>_<role>_policy` — e.g. `orders_select_owner_policy`.
- **Actor-id pattern for system writes**: when backend services must bypass user-scoped RLS, use a dedicated `system` role or a known `system_user_id` constant. Document which tables allow system-actor writes and why.
- **Role-based company checks** (`role_company_check`-style): add a `CHECK` constraint or RLS `USING` clause that joins to a `memberships` table so users can only access rows in their organization.
- **Use `auth.uid()`** in RLS policies for current-user checks, not session variables.
- **Test RLS** by connecting as a test user via `supabase.auth.signInWithPassword` and asserting that restricted rows are not returned.

### supabase-js client usage

- **Use `@supabase/ssr`** in Next.js App Router (server components, route handlers, middleware). It manages cookies for session persistence.
- **Use `@supabase/supabase-js`** for browser-only clients (SPAs without SSR) or Edge Functions.
- **Create a single client instance per request** in server contexts (not a module-level singleton) — session differs per request.
- **RLS-aware queries**: never disable RLS on a table just to simplify a query. Instead, use the service role key only in trusted server-side contexts (Edge Functions, admin scripts), and document each use.
- **Use `.throwOnError()`** when you want query errors to throw rather than checking `.error` manually.

### Edge Functions (Deno runtime)

- **One function per responsibility** — keep them small and composable.
- **Import from `https://esm.sh/` or `jsr:`** for npm packages; pin versions.
- **Use `Deno.env.get("...")`** for secrets (set via `supabase secrets set`).
- **Return `new Response(JSON.stringify(...), { headers: { "Content-Type": "application/json" } })` explicitly.**
- **Avoid long-running work** in edge functions — offload to a Postgres `pg_cron` job or a queue.

### Realtime

- **Always clean up subscriptions** — call `.unsubscribe()` / `.removeChannel()` in the component teardown (`useEffect` return, `onDestroy`, etc.).
- **Filter at the DB level** — use `filter("user_id=eq.${userId}")` on the channel, not post-receive JS filtering.
- Realtime doesn't respect RLS on the channel itself in all configurations — verify your Supabase plan / version and add explicit filters.

### Storage

- **Storage RLS mirrors table RLS**: create policies in `storage.objects` for each bucket with appropriate `USING` / `WITH CHECK` clauses.
- **Name buckets descriptively** (`avatars`, `org-documents`) and mark as private unless public read is intended.
- **Use signed URLs** for time-limited access to private objects; never expose the service role key to the browser.

## Anti-patterns

- **Don't use the service role key in the browser** — it bypasses RLS entirely.
- **Don't create a new Supabase client per query** in server components — create once per request.
- **Don't fetch without scoping to the authenticated user** — unscoped queries rely on RLS alone; add explicit `.eq("user_id", userId)` as defense-in-depth.
- **Don't ignore `.error`** on queries — check or use `.throwOnError()`.
- **Don't store secrets in Edge Function code** — use `supabase secrets set`.

## Test patterns

- Use Vitest or Jest for unit tests of business logic around Supabase calls.
- For integration tests: use a local Supabase instance (`supabase start`) with test fixtures.
- Test RLS by signing in as a non-owner user and asserting empty/denied results.
- Mock `@supabase/ssr` / `@supabase/supabase-js` clients in unit tests using `vi.mock` or `jest.mock`.

## Common pitfalls

- Cookie handling differs between browser and server SSR contexts — always use `@supabase/ssr` helpers in Next.js server code.
- `getSession()` vs `getUser()`: `getSession()` may be stale (cached); call `getUser()` when you need a fresh server-verified identity.
- Edge Function cold starts — first invocation after inactivity is slow; set `verify_jwt = false` only if you handle auth yourself.
- Migrations run via `supabase db push` in CI; local `supabase db reset` nukes local data.

## References

- [Supabase docs](https://supabase.com/docs)
- [@supabase/ssr guide](https://supabase.com/docs/guides/auth/server-side/nextjs)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Edge Functions](https://supabase.com/docs/guides/functions)
