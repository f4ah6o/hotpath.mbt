# 0002 — Production-ready roadmap

Status: polished

## Goal

Take hotpath.mbt from the completed portable timing core to a production-ready application profiling toolkit without weakening the architecture boundary established in 0001.

## Invariants

Every milestone must preserve these constraints:

- the aggregation/report core remains target-neutral
- target-specific runtime behavior stays behind narrow adapters
- canonical application source is not permanently rewritten to enable profiling
- normal application semantics are preserved by adapters
- memory use is explicitly bounded for long-running processes
- machine-readable formats are versioned before external consumers depend on them
- deterministic offline behavior exists before hosted/cloud integration
- GitHub Issues are not used; implementation packets live in this repository

## Current state

### M0 — portable runtime core — done

Delivered by PR #1:

- explicit scoped timing
- injected clocks
- deterministic repeated-label aggregation
- nested span measurements
- snapshots/reset
- text reporting with escaped delimiters
- multi-target CI

The remaining work starts at M1.

## Execution order

Use this dependency order unless a later issue documents a reason to change it:

1. M1 bounded distribution statistics
2. M2 source instrumentation
3. M3 clocks, finalization, and runtime adapters
4. M5 structured/versioned exporters
5. M4 profiler correlation
6. M7 CI regression workflow
7. M6 application adapters
8. M8 MCP
9. M9 production hardening and release gates

M5 precedes CI/MCP consumers so they can depend on a versioned report schema. M3 precedes broad adapters so timing/finalization semantics are settled first.

If a milestone expands into more than one independently testable/releasable change, split it into numbered child packets under `issues/open/` before implementation. The roadmap remains the dependency/acceptance umbrella.

## M1 — bounded distribution statistics — done

Implemented by PR #2 and recorded in `issues/done/0003-bounded-distribution-statistics.md`.

### Deliver

Add p50/p95/p99 using a bounded histogram or mergeable quantile sketch.

### Acceptance

- [x] memory ceiling is explicit and independent of observation count
- [x] merge semantics are defined and tested
- [x] deterministic behavior is tested on every supported MoonBit target
- [x] repeated equal values, sparse distributions, and extreme values are covered
- [x] snapshot/report APIs expose percentiles without retaining raw samples
- [x] overhead benchmark compares M1 against the M0 aggregate path

## M2 — source instrumentation

### Deliver

Provide opt-in instrumentation for user-defined `#hotpath.measure` annotations through a `hotpath` command/build view.

### Acceptance

- [ ] canonical source files are not permanently edited
- [ ] function instrumentation works
- [ ] explicit block instrumentation works
- [ ] a skip/escape mechanism exists
- [ ] rewritten output is reproducible
- [ ] diagnostics preserve useful original source locations
- [ ] unsupported syntax fails closed with an actionable diagnostic
- [ ] a normal `moon build` remains unaffected and uninstrumented
- [ ] generated/build-view artifacts have a deterministic cleanup policy

## M3 — clock, finalization, and runtime adapters

### Deliver

Define precise timing/finalization semantics and add high-resolution monotonic clocks where each target supports them.

### Acceptance

- [ ] each supported target documents clock source, resolution, and monotonicity
- [ ] target-specific types do not leak into the core API
- [ ] clock fallback behavior is explicit
- [ ] error/unwind behavior is tested
- [ ] async/cancellation behavior is defined before async adapters are exposed
- [ ] nested/exclusive-time direction is documented, even if exclusive time remains deferred
- [ ] cross-target tests cover zero/negative/backward clock observations

## M4 — profiler correlation

### Deliver

Correlate hotpath.mbt semantic labels with moon-pprof-style CPU/allocation profiles without duplicating low-level samplers.

### Acceptance

- [ ] an import boundary for external profiler data is defined
- [ ] source/module/function identity mapping is deterministic
- [ ] unmatched and ambiguous samples are retained and reported, not silently discarded
- [ ] correlation works without requiring network access
- [ ] fixture profiles exercise exact match, no match, and ambiguous match cases
- [ ] the correlation layer does not become a platform sampler

## M5 — structured exporters and schema

### Deliver

Introduce a versioned machine-readable report schema, JSON export, then Prometheus exposition.

### Acceptance

- [ ] report schema has an explicit version
- [ ] JSON output is deterministic for identical snapshots
- [ ] special characters and large integer values round-trip correctly
- [ ] schema compatibility tests exist
- [ ] Prometheus names/labels have deterministic escaping and collision rules
- [ ] exporters do not change profiler aggregation semantics
- [ ] consumers can reject unsupported schema versions cleanly

## M6 — application adapters

### Deliver

Add narrowly scoped wrappers/adapters where MoonBit ecosystem APIs are stable.

Initial candidates:

- HTTP client/server
- byte I/O
- channels/queues
- mutex/RwLock-like primitives
- async futures/tasks
- database/query layers

### Acceptance

- [ ] each adapter has a documented semantic boundary
- [ ] success and error paths preserve wrapped behavior
- [ ] labels have stable naming/cardinality rules
- [ ] target/runtime support is explicit
- [ ] disabled instrumentation has no hidden global side effects
- [ ] adapters are independently testable and can be released incrementally

## M7 — CI regression workflow

### Deliver

Compare reports against repository-owned baselines and enforce budgets/thresholds.

### Acceptance

- [ ] baseline format is versioned
- [ ] comparison is deterministic and works offline
- [ ] absolute and relative thresholds are supported
- [ ] missing/new/removed labels have explicit policy
- [ ] verdicts are machine-readable
- [ ] human-readable output explains the regressions that caused failure
- [ ] CI examples cover pass, fail, and schema-mismatch cases

## M8 — MCP

### Deliver

Expose read-only profiler/report inspection first.

Initial tools should support:

- discover reports
- summarize hot paths
- compare baseline/current reports
- explain regressions

### Acceptance

- [ ] first release is read-only
- [ ] tool schemas depend on the versioned M5 report model
- [ ] large reports are bounded/paginated
- [ ] malformed or unsupported reports fail closed
- [ ] no implicit upload/cloud mutation occurs
- [ ] any future mutation/upload capability requires a separate issue packet and explicit design

## M9 — production hardening and release gates

### Deliver

Establish the release bar for production use.

### Acceptance

- [ ] overhead benchmarks run across supported targets
- [ ] bounded-memory stress tests cover long-running aggregation
- [ ] concurrency/thread-safety model is documented and tested where applicable
- [ ] compatibility matrix is maintained
- [ ] report schema compatibility/migration policy is documented
- [ ] fuzzing or property-based testing covers parsers/rewriters/report decoding where suitable
- [ ] release/publish checklist includes format, check, all-target tests, compatibility fixtures, and benchmarks
- [ ] public API stability/deprecation policy is documented
- [ ] README reflects the actual production support matrix

## Production-ready exit criterion

hotpath.mbt may be described as production-ready only when M1–M9 acceptance is complete or an explicit issue records why a milestone is intentionally deferred without violating the invariants above.
