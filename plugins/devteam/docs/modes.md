# Mode reference

Two persistent modes per project. Stored in `.devteam/mode`.

## work-together (default)

LEAD checks in with you at decision points:
- Before each phase boundary
- On every specialist question packet (funneled with two recommendations)
- Before destructive actions (push, deploy, rm, force-push, drop table)

LEAD uses utility agents sparingly — you're available.

## autonomous

LEAD uses best judgment:
- Decides classification silently; mentions in opening only
- Phase transitions happen without check-ins
- Specialist questions: pre-flight with utility agents; answers self if confident; halts cleanly with notification only if still ambiguous after pre-flight
- Heavier utility-agent use (substitute for user input)
- Final report at end

**Hard rules in both modes:**
- Destructive actions always confirm.
- Twice-failed specialist always escalates to user.

## Switching mode

Persistent: `/lead-mode work-together`, `/lead-mode autonomous`
This run only: `/lead --mode autonomous "task"`
Natural language: "go autonomous", "check in with me from now on"

Notifications: `--notify` / `--no-notify` flags; default ON in autonomous, OFF in work-together.

Mid-flight switch happens at the next safe point. MODE entry logged to slack.
