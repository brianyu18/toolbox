# brains

Workflow router skills for Claude Code. One router (`/brains`) looks at a new task, classifies it by complexity, and dispatches to the right sub-skill. Each sub-skill is a playbook that chains the right combination of [superpowers](https://github.com/obra/superpowers) and [gstack](https://github.com/gstack) skills for that class of work.

The point: stop re-deciding "which process do I use" every time a task arrives. Decide once, in the playbook, then just invoke the router.

This repo is a **Claude Code plugin marketplace** containing one plugin (`brains`).

## Skill list

| Skill | When to use | What it chains |
|---|---|---|
| `brains` | At the start of any non-trivial dev task or project kickoff. This is the router. | Classifies the task, recommends one of the four below, invokes it |
| `brains-simple` | One-file edit, config tweak, doc change, factual question | Read → edit → `superpowers:verification-before-completion` |
| `brains-bug` | Unexpected behavior, test failure, "why is this broken" | `/investigate` (or `superpowers:systematic-debugging`) → `superpowers:test-driven-development` (repro test first) → `/review` → commit |
| `brains-feature` | New feature of medium scope in an existing product | `superpowers:brainstorming` → `superpowers:writing-plans` → `superpowers:test-driven-development` → `/review` + `/codex` → `/ship` |
| `brains-complex` | New subsystem, multi-file rewrite, user-visible product change | `superpowers:brainstorming` → `superpowers:writing-plans` → `/plan-eng-review` (+ `/plan-ceo-review` if scope is squishy, `/plan-design-review` if UI) → `/autoplan` → `superpowers:using-git-worktrees` + `superpowers:subagent-driven-development` → `/qa` → `/review` + `/codex` → `/ship` → `/canary` |

## How the router fires

**Soft trigger (default).** The router skill's description says "Use at the start of any non-trivial development task..." The model reads this in its skill list and invokes the router unprompted when a task arrives. No hook, no per-turn cost. Relies on model judgment.

**Hard trigger (optional escalation).** If the model skips routing when it shouldn't, enable a `UserPromptSubmit` hook that injects a reminder every turn. A ready-to-activate stub lives at `plugins/brains/hooks/hooks.json.example` — rename it to `hooks.json` and Claude Code picks it up on next session.

Rule for escalating: if the router gets skipped on 5+ real task kickoffs, flip the hook on.

## Install

Inside a Claude Code session, run these slash commands:

```
/plugin marketplace add brianyu18/brains
/plugin install brains@brains
```

The first command registers this repo as a marketplace. The second installs the `brains` plugin from it. Works identically on every machine you do this on.

## Updating

Inside Claude Code:

```
/plugin marketplace update brains
/plugin update brains@brains
```

## Uninstalling

```
/plugin uninstall brains@brains
/plugin marketplace remove brains
```

## Repo structure

```
brains/                                     # marketplace root
├── .claude-plugin/
│   └── marketplace.json                    # marketplace manifest
├── plugins/
│   └── brains/                             # the plugin
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── skills/
│       │   ├── brains/SKILL.md             # router
│       │   ├── brains-simple/SKILL.md
│       │   ├── brains-bug/SKILL.md
│       │   ├── brains-feature/SKILL.md
│       │   └── brains-complex/SKILL.md
│       └── hooks/
│           └── hooks.json.example          # optional hard-trigger stub
└── README.md
```
