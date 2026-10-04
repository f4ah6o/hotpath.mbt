# 0002 — Production-ready roadmap

Status: open

## M0 — portable runtime core

Deliver the first explicit timing API and stable aggregate snapshot/report model.

Acceptance is defined in 0001.

## M1 — bounded distribution statistics

Design a bounded histogram or mergeable quantile sketch with explicit memory ceilings. Add p50/p95/p99 only after deterministic cross-target behavior and merge semantics are tested.

## M2 — source instrumentation

Implement a parser/rewriter for user-defined `#hotpath.measure` attributes.

Requirements:
- do not require permanent generated edits to canonical sources
- preserve source locations for diagnostics
- support function and explicit block instrumentation
- provide an escape/skip attribute
- produce reproducible instrumented output
- normal `moon build` remains untouched

## M3 — clock and runtime adapters

Provide high-resolution monotonic clocks per supported target behind the core clock boundary. Define async/cancellation behavior and guaranteed finalization where MoonBit runtime semantics permit it.

## M4 — profiler correlation

Integrate report import/correlation with moon-pprof-style CPU and allocation profiles. hotpath.mbt should annotate/align application labels rather than duplicate low-level samplers.

## M5 — structured exporters

Add versioned JSON output first, then Prometheus exposition. The stable snapshot schema must be versioned before CI/MCP consumers depend on it.

## M6 — application adapters

Add narrowly-scoped wrappers/adapters for:
- HTTP client/server
- byte I/O
- channels/queues
- mutex/RwLock-like primitives
- async futures/tasks where applicable
- database/query layers when stable MoonBit ecosystem APIs exist

Adapters must preserve normal application semantics and document target/runtime limitations.

## M7 — CI regression workflow

Add baseline comparison, budgets, regression thresholds, and machine-readable verdicts. Keep policy files in-repository. Support deterministic offline comparison before any hosted service integration.

## M8 — MCP

Expose read-only profiler/report inspection first: discover reports, summarize hot paths, compare baselines, explain regressions. Mutation or cloud-upload actions require separate explicit design.

## M9 — production hardening

- overhead benchmarks across targets
- bounded-memory stress tests
- concurrency/thread-safety model
- compatibility matrix
- versioned report schema
- docs and migration policy
- fuzz/PBT where suitable
- release/publish gates
