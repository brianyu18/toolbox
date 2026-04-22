# brains

Workflow router skills for Claude Code. One router (`/brains`) looks at a new task, classifies it by complexity, and dispatches to the right sub-skill. Each sub-skill is a playbook that chains the right combination of [superpowers](https://github.com/obra/superpowers) and [gstack](https://github.com/gstack) skills for that class of work.

The point: stop re-deciding "which process do I use" every time a task arrives. Decide once, in the playbook, then just invoke the router.

## Skill list

| Skill | When to use | What it chains |
|---|---|---|
| `/brains` | At the start of any non-trivial dev task or project kickoff. This is the router. | Classifies the task, recommends one of the four below, invokes it |
| `/brains-simple` | One-file edit, config tweak, doc change, factual question | Read → edit → `superpowers:verification-before-completion` |
| `/brains-bug` | Unexpected behavior, test failure, "why is this broken" | `/investigate` (or `superpowers:systematic-debugging`) → `superpowers:test-driven-development` (repro test first) → `/review` → commit |
| `/brains-feature` | New feature of medium scope in an existing product | `superpowers:brainstorming` → `superpowers:writing-plans` → `superpowers:test-driven-development` → `/review` + `/codex` → `/ship` |
| `/brains-complex` | New subsystem, multi-file rewrite, user-visible product change | `superpowers:brainstorming` → `superpowers:writing-plans` → `/plan-eng-review` (+ `/plan-ceo-review` if scope is squishy, `/plan-design-review` if UI) → `/autoplan` → `superpowers:using-git-worktrees` + `superpowers:subagent-driven-development` → `/qa` → `/review` + `/codex` → `/ship` → `/canary` |

## How the router fires

**Soft trigger (default).** `/brains`'s description says "Use at the start of any non-trivial development task or project kickoff to select the right workflow." The model reads this in its skill list and invokes the router unprompted when a task arrives. No hook, no per-turn cost. Relies on model judgment.

**Hard trigger (optional escalation).** If the model skips routing when it shouldn't, enable a `UserPromptSubmit` hook that injects a reminder every turn. A ready-to-activate stub lives at `hooks/hooks.json.example` — rename it to `hooks/hooks.json` and Claude Code picks it up on next session.

Rule for escalating: if `/brains` gets skipped on 5+ real task kickoffs, flip the hook on.

## Install

On each machine:

```
mkdir -p ~/.claude/plugins
git clone git@github.com:brianyu18/brains.git ~/.claude/plugins/brains
```

Or with HTTPS:

```
git clone https://github.com/brianyu18/brains.git ~/.claude/plugins/brains
```

Restart Claude Code. The router and sub-skills appear in your skill list.

## Structure

```
brains/
├── .claude-plugin/
│   └── plugin.json              # manifest
├── skills/
│   ├── brains/SKILL.md          # router
│   ├── brains-simple/SKILL.md
│   ├── brains-bug/SKILL.md
│   ├── brains-feature/SKILL.md
│   └── brains-complex/SKILL.md
├── hooks/
│   └── hooks.json.example       # optional hard-trigger stub
└── README.md
```

## Updating

```
cd ~/.claude/plugins/brains && git pull
```

Changes take effect next Claude Code session.
