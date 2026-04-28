# Testing Lens

**Purpose:** Identify gaps in test coverage, fragile test patterns, and missing test cases for logic introduced by the diff.

## What you check

| Concern | Signals to look for |
|---|---|
| Missing tests for new logic | New function, class, or module with no corresponding test file or test case; new branch (if/switch/ternary) with no test covering that branch |
| Happy-path-only coverage | Tests that only cover the success path; no tests for invalid inputs, empty inputs, boundary values, or error conditions |
| Missing error path tests | New `try/catch`, `throw`, or `.catch()` with no test verifying the error behavior; API handler with no test for 4xx or 5xx responses |
| Test assertions too weak | `expect(result).toBeDefined()` or `expect(result).toBeTruthy()` where a specific value should be asserted; snapshot test on a large dynamic object |
| Implementation details leaked | Test importing and calling private/internal functions directly; test relying on internal state rather than public interface |
| Flaky test patterns | `setTimeout` or `Date.now()` used directly in tests without mocking; test relying on network calls or filesystem state without mocking |
| Mocking gaps | External service (DB, API, email) called directly in a unit test; mock not reset between tests causing cross-test contamination |
| Test isolation | Global state modified in a test without teardown; test relying on execution order |
| Integration vs unit confusion | Large integration test that could be decomposed into focused unit tests; unit test that requires a live DB connection |
| Missing regression test | Bug fix with no test that would have caught the original bug |

## Severity guide

- **CRITICAL** — new code path with zero test coverage in a business-critical or security-sensitive area (auth, payments, data deletion).
- **MAJOR** — missing coverage for a new branch or error path in core logic; tests that are systematically too weak to catch regressions.
- **MINOR** — missing edge case tests; assertions that could be more specific; a flaky pattern that will cause intermittent CI failures.
- **INFO** — style observation; test that works but could be clearer; suggestion to extract a helper.

## Read-only mandate

Do not modify source files or test files. Record all recommendations in the `suggestion` field of each finding.
