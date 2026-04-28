# Question Packet — the specialist → LEAD interface

Every specialist returns one of three states.

## status: complete

```json
{
  "status": "complete",
  "phase": "PLAN",
  "summary": "Plan written, 4 partitions identified",
  "artifacts": [".devteam/state/plan.md"],
  "next_phase_ready": true,
  "notes_for_lead": "Backend on critical path; dispatch first if sequential."
}
```

## status: blocked

```json
{
  "status": "blocked",
  "phase": "PLAN",
  "question": "RHF or Formik?",
  "options": [
    { "id": "A", "label": "react-hook-form", "tradeoff": "smaller bundle" },
    { "id": "B", "label": "formik", "tradeoff": "team familiarity" }
  ],
  "specialist_recommendation": "A",
  "reasoning": "Bundle budget tight, RHF already in 2 forms",
  "context_needed_to_resume": "Form library decision"
}
```

## status: failed

```json
{
  "status": "failed",
  "phase": "BUILD",
  "failure_kind": "tool_error",
  "details": "npm test exited 130",
  "partial_artifacts": ["src/components/settings.tsx"]
}
```

LEAD retries once with addendum. On second failure: escalate to user regardless of mode.
