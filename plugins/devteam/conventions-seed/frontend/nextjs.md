# Next.js App Router Conventions

## Stack overview

Next.js 13+ App Router. React Server Components (RSC) by default; opt into client with `"use client"`. File-system routing under `app/`. TypeScript-first. Deployment target: Vercel or Node server.

## Conventions

### Server vs. client components

- **Default to Server Components.** Only add `"use client"` when the component needs browser APIs, event handlers, or React hooks (`useState`, `useEffect`, etc.).
- **Push `"use client"` to leaf nodes.** Keep wrappers as server components; only the interactive leaf gets the directive.
- **Data fetching belongs in Server Components** — fetch directly in the component body (async RSC), not in `useEffect`.

### Server actions vs. route handlers

- **Use Server Actions** (`"use server"`) for form mutations and simple data writes triggered from the UI. Colocate them in the same file or a `_actions.ts` sibling.
- **Use Route Handlers** (`app/api/.../route.ts`) for webhook endpoints, third-party callbacks, and any HTTP API that must be callable from outside the app.
- Never call a Server Action from a Route Handler or vice versa.

### Routing and special files

- `loading.tsx` — React Suspense boundary for the route segment; shown during async server render.
- `error.tsx` — must be `"use client"`; receives `error` and `reset` props. Handle gracefully, log to Sentry.
- `not-found.tsx` — shown when `notFound()` is called or no route matches; keep it static (no data fetching).
- `layout.tsx` — persistent UI around a segment; avoid fetching volatile data here (it caches aggressively).

### Metadata API

- Export `metadata` (static) or `generateMetadata` (dynamic) from `page.tsx` or `layout.tsx`. Do not use `<Head>` from `next/head` in App Router.
- `generateMetadata` can be async and receives `params` and `searchParams`.

### Route segment config

- `export const dynamic = "force-dynamic"` — opt segment out of caching. Use sparingly; prefer revalidation.
- `export const revalidate = 60` — ISR: revalidate every N seconds.
- `export const runtime = "edge"` — edge runtime; no Node.js APIs.

### `generateStaticParams`

- Export from dynamic segments to pre-render at build time. Return an array of param objects.
- Combine with `revalidate` for hybrid static + ISR.

### Middleware

- Lives at `middleware.ts` in project root (or `src/`). Runs on the edge.
- Use for auth redirects, locale detection, A/B testing — NOT for heavy computation.
- Always define a `matcher` to scope execution; avoid running on `_next/static` or API routes unnecessarily.

## Anti-patterns

- **Don't `"use client"` at the top of large component trees** — defeats RSC performance gains.
- **Don't fetch in `layout.tsx` for data that varies by user** — layout caches more aggressively; use a Server Component child or a `cookies()`-gated fetch.
- **Don't mix `pages/` and `app/` routing for the same feature** — migrating incrementally is fine, but keep features in one router.
- **Don't use `useRouter().push()` for form submissions** — use Server Actions with `redirect()` instead.
- **Don't ignore `loading.tsx`** — without it, the entire segment blocks until the async server render completes.
- **Don't put secrets in client components** — environment variables without `NEXT_PUBLIC_` prefix are server-only; don't pass them as props to `"use client"` components.

## Test patterns

- **Jest + React Testing Library** for client component unit tests.
- **Vitest** for ESM-native projects or where Jest config is painful.
- **Playwright** for end-to-end: test actual navigation, form submissions, auth flows. Use `page.goto` with the Next.js dev server or a preview deploy.
- Mock `next/navigation` (`useRouter`, `usePathname`, `useSearchParams`) in unit tests with `jest.mock('next/navigation')`.
- Test Server Actions by calling them directly in integration tests; assert DB state.

## Common pitfalls

- `cookies()` / `headers()` called in a cached context throws at runtime — call them only in dynamic segments or Server Actions.
- `searchParams` in `page.tsx` is not a plain object in the App Router — it's a `ReadonlyURLSearchParams`-like object; don't spread it.
- Waterfall fetches: parallel-fetch with `Promise.all` in RSC rather than sequential awaits.
- Image `alt` text missing — `next/image` does not enforce it but it's an a11y violation.

## References

- [Next.js App Router docs](https://nextjs.org/docs/app)
- [Server Components RFC](https://react.dev/blog/2020/12/21/data-fetching-with-react-server-components)
- [Next.js Middleware](https://nextjs.org/docs/app/building-your-application/routing/middleware)
