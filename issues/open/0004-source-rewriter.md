# 0004 — deterministic source rewriter

Status: open

## Goal

Implement the independently testable source-to-source rewrite portion of M2 without mutating canonical MoonBit sources.

## Scope

- recognize function-level `#hotpath.measure` annotations
- recognize explicit block instrumentation directives
- support an explicit `skip=true` escape hatch
- preserve line numbers for useful compiler diagnostics
- fail closed on unsupported or ambiguous syntax
- produce byte-for-byte reproducible rewritten source for the same input

## Acceptance

- [ ] function instrumentation rewrites to the hotpath runtime
- [ ] explicit block instrumentation rewrites to the hotpath runtime
- [ ] `skip=true` leaves the target uninstrumented
- [ ] line count is preserved
- [ ] async/unsupported forms fail with original source path and line
- [ ] repeated rewrites from the same canonical input are identical
- [ ] focused rewriter tests pass
