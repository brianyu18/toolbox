# React Conventions

## Stack overview

Functional React with hooks, TypeScript-first. SSR via Next.js or framework of choice; client-side state via hooks + context.

## Conventions

- **Functional components only.** No class components in new code.
- **One component per file.** File name matches default export (PascalCase).
- **Props interface above component**, named `<ComponentName>Props`.
- **Custom hooks prefixed `use*`** (React enforces this for hook detection).
- **Co-locate tests** as `<Component>.test.tsx` next to the component file.

## Anti-patterns

- **Don't use `useEffect` for derived state** — derive inline or with `useMemo`. `useEffect` is for synchronizing with external systems.
- **Don't pass setState through 5+ levels** — use Context or a store (Zustand, etc.).
- **Don't mount-time-fetch in components** — use a data layer (TanStack Query, RTK Query, framework loader).
- **Don't `useState` with the same shape repeatedly** — define a typed reducer.
- **Don't use raw-HTML render APIs** (the React ones whose name suggests danger, or Vue's `v-html`) — they enable XSS if content isn't sanitized; prefer escaping or a sanitizer (DOMPurify) at the trust boundary.
- **Don't export anonymous default** — name the function for stack traces.

## Test patterns

- React Testing Library, not Enzyme.
- Test behavior (what user sees / does), not implementation.
- Use `screen.getByRole(...)` over `getByTestId` when possible (accessibility-aligned).
- Mock at the boundary (network, not internals).

## Common pitfalls

- Stale closures in `useEffect` / `useCallback` deps.
- Re-renders triggered by inline object/array literals as props (memoize or hoist).
- Missing `key` on list items.

## References

- [React docs](https://react.dev)
- [React Testing Library](https://testing-library.com/docs/react-testing-library/intro/)
