# 0001 — Architecture and product boundary

Status: done

## Goal

Define the stable product boundary for a MoonBit-first application profiler: explicit application-level instrumentation and deterministic semantic aggregation, with lower-level CPU/allocation sampling delegated to existing profilers.

## Decisions

### Ownership boundary

hotpath.mbt owns:

- named function/block instrumentation
- deterministic aggregation and snapshots
- stable report models and exporters
- application adapters for HTTP, I/O, channels/queues, locks, async work, and database/query layers where APIs are stable
- CI regression comparison
- report inspection and analysis interfaces such as MCP

Sampling CPU/allocation profiling is not reimplemented here. Correlation with tools such as moon-pprof belongs at the report/tooling layer.

### Portability

The aggregation core stays target-neutral across native, js, wasm, and wasm-gc where practical.

Clock access is isolated behind an injected `() -> Int64` contract. Target-specific high-resolution or monotonic clocks may be added only behind narrow adapters and must not leak target-specific types into the core API.

### Opt-in instrumentation

Manual API calls incur overhead only where applications explicitly call hotpath.mbt.

Future source instrumentation must not permanently mutate canonical application sources. A normal `moon build` remains uninstrumented unless the application directly calls the runtime API.

### Aggregation

The baseline aggregate model is:

- calls
- total duration
- minimum duration
- maximum duration
- integer average duration
- deterministic first-observation ordering

Percentiles are intentionally excluded until a bounded-memory, mergeable distribution design is accepted.

### Nested timing

Nested measurements are independent semantic spans. Outer elapsed time includes inner work; inner elapsed time is also recorded under its own label.

Exclusive/self time requires an explicit span-stack design and is deferred.

### Error/unwind behavior

The initial closure-based measurement records normal returns only. Guaranteed recording across raised errors or cancellation requires a runtime-safe cleanup design and is deferred.

## Acceptance

- [x] portable MoonBit library package exists
- [x] manual scoped timing works
- [x] custom clock injection works
- [x] repeated labels aggregate
- [x] nested spans produce sensible independent rows
- [x] snapshot/report ordering is deterministic
- [x] reset makes tests deterministic
- [x] negative/zero durations cannot corrupt aggregates
- [x] README documents scope and usage
- [x] pawurb/hotpath-rs is credited in `ACKNOWLEDGEMENTS.md`
- [x] repository-local issue packets are used instead of GitHub Issues
- [x] `moon fmt --check` passes
- [x] `moon check --target all` passes
- [x] `moon test --target all` passes

## Evidence

PR #1 (`feat: bootstrap hotpath.mbt profiling runtime`) completed the first slice.

Its recorded verification used MoonBit `0.1.20260920` and passed:

- `moon fmt --check`
- `moon check --target all`
- `moon test --target all`
  - wasm: 6/6
  - wasm-gc: 6/6
  - js: 6/6
  - native: 6/6

## Follow-up

Execution after M0 is tracked by `issues/polished/0002-production-roadmap.md`.
