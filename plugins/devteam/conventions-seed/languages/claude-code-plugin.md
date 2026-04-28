# Claude Code Plugin Authoring Conventions

## Stack overview

Claude Code plugins extend the Claude Code CLI with skills (slash commands with rich markdown prompts), agents (subagent personas with defined tools), commands (simple slash-command entry points), and hooks (event-driven shell scripts). The plugin system is managed by the Claude Code marketplace. All paths inside skill/agent/command content resolve `${CLAUDE_PLUGIN_ROOT}` at brief-load time.

## Conventions

### Plugin manifest (`plugin.json`)

Lives at `<plugin-dir>/.claude-plugin/plugin.json`. Required fields:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "One sentence: what the plugin does.",
  "author": { "name": "Your Name" },
  "repository": "https://github.com/you/my-plugin",
  "license": "MIT",
  "keywords": ["tag1", "tag2"],
  "requires": {
    "plugins": [
      { "name": "superpowers", "marketplace": "claude-plugins-official", "min_version": "5.0.0" }
    ]
  }
}
```

- `name` must be kebab-case, unique within the marketplace.
- `version` follows semver.
- `requires.plugins` is optional; omit if no plugin dependencies.
- `keywords` improve discoverability — include the problem domain, not just tool names.

### Skill frontmatter (`skills/<name>/SKILL.md`)

```yaml
---
name: my-skill
description: >
  Use this skill when the user wants to <action>. Provide the description
  in the imperative mood so Claude Code's skill router can match correctly.
---
```

- `name` is the slash-command name: `/my-skill`.
- `description` is the key signal for skill routing. Be specific about the trigger condition — vague descriptions cause the router to skip the skill.
- Skills may include sibling markdown files for sub-context; reference them via `${CLAUDE_PLUGIN_ROOT}/skills/<name>/` paths in the skill body.

### Agent frontmatter (`agents/<name>.md`)

```yaml
---
name: my-agent
description: Use this agent when <context>. Describe the role and narrow scope.
tools: Read, Grep, Glob, Bash, Edit, Write
---
```

- `tools` is a comma-separated list. List only the tools the agent actually needs — least-privilege principle.
- Agents are dispatched by controllers (skills or the main agent); they do not invoke other agents.
- Keep the agent body focused on one responsibility. Avoid orchestration logic inside agents.

### Command frontmatter (`commands/<name>.md`)

```yaml
---
description: Short description of what /name does.
---
```

- The filename (minus `.md`) is the command name: `commands/foo.md` → `/foo`.
- Commands are lightweight entry points. Use `$ARGUMENTS` in the body to receive user input.
- For complex routing logic, invoke a skill from the command body rather than duplicating logic.

### Hooks (`hooks/hooks.json` and `hooks.json.example`)

```json
{
  "SessionStart": [
    { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh" }
  ],
  "UserPromptSubmit": [
    { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-prompt.sh" }
  ]
}
```

- Ship `hooks.json.example` in the plugin; let `/setup` or the user copy it to `hooks.json` to activate.
- Supported event types: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`.
- Hook scripts must be executable (`chmod +x`) and exit 0 on success.
- `${CLAUDE_PLUGIN_ROOT}` in hook commands is expanded at registration time; ensure it's set when `hooks.json` is written.
- Hooks registered at the `~/.claude/settings.json` level fire for all sessions; plugin-local `hooks.json` fires only when the plugin is active.

### `${CLAUDE_PLUGIN_ROOT}` expansion

- `${CLAUDE_PLUGIN_ROOT}` resolves to the plugin's install directory at the moment a skill brief or agent file is loaded.
- **Resolve it at brief time** — write paths like `${CLAUDE_PLUGIN_ROOT}/path/to/file` in skill/agent content and let the harness expand them. Do not read the variable via `Bash` or try to resolve it with filesystem traversal.
- The variable is available in skill bodies, agent bodies, command bodies, and hook command strings.

### Marketplace structure (`.claude-plugin/marketplace.json`)

```json
{
  "name": "my-marketplace",
  "owner": { "name": "Author Name" },
  "metadata": {
    "version": "0.1.0",
    "description": "What this marketplace contains."
  },
  "plugins": [
    {
      "name": "my-plugin",
      "version": "1.0.0",
      "description": "Short description.",
      "source": "./plugins/my-plugin"
    }
  ]
}
```

- The `source` path is relative to the marketplace root.
- A single repo can host multiple plugins; list each in `plugins`.
- `marketplace.json` lives at the repo's `.claude-plugin/marketplace.json`.

## Anti-patterns

- **Don't hardcode user home paths** (`/Users/brian/...`) in skill content or hook commands. Use `${CLAUDE_PLUGIN_ROOT}`, `~`, or environment variables.
- **Don't `cat` files in slash commands when the Read tool is available** — `cat` is a shell command that requires a `Bash` tool call (permission prompt); Read is direct and needs no permission.
- **Don't make subagents read plan files when the controller can extract** — extract the relevant section from a plan file in the controller (skill/main agent), then pass only the needed excerpt to the subagent brief. Sending subagents to re-read large documents wastes tokens and latency.
- **Don't put orchestration in agents** — agents execute work, skills/the main agent orchestrate. An agent that dispatches to other agents creates untrackable fan-out.
- **Don't skip the `description` in skill frontmatter** — without it the router cannot match the skill to user intent and the skill will never fire.
- **Don't register hooks globally when plugin-local scope suffices** — global hooks in `settings.json` fire for every session regardless of project; prefer plugin-local `hooks.json` for project-specific setup.

## Test patterns

There is no automated test runner for Claude Code plugins. Validate by:
- Manually invoking each skill after `plugin install` and verifying expected behavior.
- For hook scripts: run them standalone (`sh hooks/session-start.sh`) and assert exit code + output.
- For skill routing: test ambiguous command names with the router and confirm the right skill is selected.
- Add a `bin/smoke-test.sh` that exercises critical skill paths headlessly if the plugin has CLI-driven logic.

## Common pitfalls

- `${CLAUDE_PLUGIN_ROOT}` is undefined if the plugin isn't installed via the marketplace; test installed, not from the source directory.
- Skill `name` must exactly match the intended slash command. A mismatch means the command exists but invokes a different or no skill.
- `hooks.json` (not `.example`) must exist for hooks to fire; the example file is documentation-only.
- Agents with too many tools cause the model to over-reach. Start with the minimum tool set.
- Large skill bodies (10k+ tokens) slow down every invocation. Extract stable reference content into sibling markdown files and `${CLAUDE_PLUGIN_ROOT}`-reference them.

## References

- [Claude Code plugin authoring guide](https://docs.anthropic.com/en/docs/claude-code/plugins)
- [Claude Code skills documentation](https://docs.anthropic.com/en/docs/claude-code/skills)
- [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)
