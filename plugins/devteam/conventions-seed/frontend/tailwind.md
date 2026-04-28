# Tailwind CSS Conventions

## Stack overview

Utility-first CSS framework. Compose styles inline via class names. v3+ uses JIT for fast, dead-code-free builds.

## Conventions

- **Group classes by category in this order**: layout (flex/grid), positioning (absolute, top), spacing (p, m), sizing (w, h), typography (text, font), color (bg, text), interaction (hover, focus), other.
- **Extract repeated combinations** into a component (not `@apply` in CSS — keeps colocated).
- **Use design tokens via tailwind.config**: extend theme with project colors/spacing rather than arbitrary values like `mt-[13px]`.
- **Responsive prefixes mobile-first**: write base styles, then `sm:`, `md:`, `lg:` overrides.
- **Use `@apply` sparingly** — only for true CSS primitives where utilities would be too verbose.

## Anti-patterns

- **Don't fight the design system** with arbitrary values everywhere — extend the config instead.
- **Don't use `important!`** — the cascade is fine.
- **Don't re-implement utilities** in custom CSS — Tailwind's are well-tested.

## Test patterns

Visual regression tests (Percy, Chromatic) catch class-related regressions. Static class strings are robust to typos via type-checking with `tailwindcss-classnames` or `cva`.

## Common pitfalls

- Purge config too aggressive → classes not found in production. Configure `content:` paths to include all template files.
- Dynamic class names get purged. Use full class strings or `cva`.

## References

- [Tailwind docs](https://tailwindcss.com/docs)
- [tailwindcss-classnames](https://github.com/muhammadsammy/tailwindcss-classnames)
