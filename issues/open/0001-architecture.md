# 0001 — Architecture and product boundary

Status: open

## Goal

Build a MoonBit-first application profiler that makes application-level hot paths cheap to instrument, deterministic to report, and easy to correlate with lower-level CPU/allocation profiles.

## Boundary

hotpath.mbt owns explicit application instrumentation and semantic aggregation: named functions/blocks, future adapters for I/O/channels/locks/HTTP, stable report models, exporters, CI regression comparison, and MCP-facing analysis.

Sampling CPU/allocation profiling is a separate concern. Prefer integrating with existing MoonBit profilers such as moon-pprof instead of reimplementing platform samplers. Correlation belongs at the report/tooling layer.

## Portability model

The aggregation core must stay target-neutral across native, js, wasm, and wasm-gc where practical. Clock access is isolated behind an injected `() -> Int64` contract. The first portable default uses `@env.now()` in milliseconds; later target adapters may provide monotonic/high-resolution clocks without changing the aggregate model.

Target-specific adapters are permitted only at narrow boundaries and must not leak target-specific types into the core API.

## Opt-in / zero-overhead direction

Manual calls incur overhead only where applications explicitly call hotpath.mbt.

The planned source-instrumentation path must not mutate the canonical application source merely to enable profiling. `#hotpath.measure` is a user-defined attribute ignored by the compiler. A future `hotpath` command will parse annotated sources, generate/instrument a temporary build view, and delegate to `moon`. A normal `moon build` remains uninstrumented and has zero hotpath runtime cost unless the application explicitly calls the runtime API.

## Aggregation

The initial runtime aggregates by label and reports calls, total, minimum, maximum, and integer average duration. First-observation ordering is preserved for deterministic snapshots.

Exact percentiles are deliberately deferred: retaining every sample is unbounded. A later bounded histogram/quantile design must define memory limits and merge semantics before p50/p95/p99 become part of the stable model.

## Nested timing

Nested measurements are independent semantic spans. Outer elapsed time includes inner work; inner elapsed time is also recorded under its own label. Exclusive/self time is a later feature and requires an explicit span stack design.

## Error/unwind boundary

The first closure-based measurement records only normal returns. Guaranteed recording across raised errors/cancellation needs a language/runtime-safe cleanup mechanism and is not claimed by this slice.

## First-slice acceptance

- portable MoonBit library package exists
- manual scoped timing works
- custom clock injection works
- repeated labels aggregate
- nested spans produce sensible independent rows
- snapshot/report ordering is deterministic
- reset makes tests deterministic
- negative/zero durations cannot corrupt aggregates
- README documents scope and usage
- pawurb/hotpath-rs is credited in ACKNOWLEDGEMENTS.md
- GitHub Issues are not used; project work lives under issues/open
- `moon check --target all`, `moon test --target all`, and `moon fmt --check` pass in CI
