# devteam conventions library

Bundled SEED for the conventions library. On `/lead-setup`, contents here are copied to `~/.claude/devteam/conventions/`.

## Adding a new stack

1. Drop a markdown file in the right folder.
2. Use standard sections (see existing files): Stack overview, Conventions, Anti-patterns, Test patterns, Common pitfalls, References.
3. Add an entry to `index.json` with detection signals (structured form: `{"file_exists": ...}` or `{"file_contains": {"file": ..., "pattern": ...}}`).
4. LEAD will auto-load your file when signals match (via `bin/devteam-detect-stack.sh`).

## Standard sections

```markdown
# <Stack> Conventions

## Stack overview
## Conventions
## Anti-patterns
## Test patterns
## Common pitfalls
## References
```

## Customizing

After `/lead-setup` copies seeds to `~/.claude/devteam/conventions/`, edit those copies — never the seed files in the plugin (overwritten on plugin upgrade).
