# Pine Script Conventions

## Stack overview

Pine Script is TradingView's domain-specific language for indicators and strategies. Compiled and run on TradingView's servers; output is plotted on charts. Versions: v5 and v6 (current). v6 has stricter type checking.

## Conventions

- **Version pragma**: every script starts with `//@version=5` or `//@version=6`.
- **Declaration**: `indicator("Name", ...)` or `strategy("Name", ...)`.
- **Naming**: snake_case for variables, PascalCase for user-defined types.
- **Inputs grouping**: organize `input.*` calls into logical groups via `group=` parameter.
- **Use `simple`/`series`/`const` qualifiers explicitly in v6** — don't rely on inference.

## Anti-patterns

- **Don't use `var` for series-state that should reset** — use `varip` for last-bar continuity, plain assignment for per-bar.
- **Don't compute heavy logic outside `if barstate.islast`** when a single-bar update is acceptable.
- **Don't plot too many series** — TradingView limits to ~64 plots per script.
- **Don't request data via `request.security` inside loops** — limit is small and cumulative.

## Test patterns

Pine Script lacks a test framework. Validate by:
- Visual chart inspection at known historical events.
- Compare alerts/signals against ground truth from Excel/sheet calculations.
- Use `label.new` to debug-print intermediate values.

## Common pitfalls

- Repainting (using future-bar data unintentionally) — always validate signals don't change after the bar closes.
- `na` propagation in math — wrap with `nz()` to default to 0.
- Confusing `iff()` (deprecated) with ternary `?:`.

## References

- [Pine Script v6 reference](https://www.tradingview.com/pine-script-reference/v6/)
- [Pine Script user manual](https://www.tradingview.com/pine-script-docs/)
