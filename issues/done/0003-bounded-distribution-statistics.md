# 0003 — Bounded distribution statistics

Status: done

## Goal

Complete M1 from the production roadmap by adding bounded p50/p95/p99 statistics without retaining raw observations or weakening deterministic cross-target behavior.

## Design

Each measurement label owns a fixed 64-counter logarithmic histogram in addition to the M0 aggregate counters.

- bucket 0 represents zero milliseconds
- positive durations use logarithmic power-of-two ranges
- percentile estimates use the selected bucket upper bound and are capped by the observed maximum
- negative durations continue to clamp to zero before aggregation
- memory use is fixed at 64 integer counters per label regardless of observation count
- `Profiler::merge` merges aggregate counters and corresponding histogram buckets
- existing labels retain first-observation order; labels unique to the merged profiler are appended in its order
- raw observations are never retained

## Acceptance

- [x] memory ceiling is explicit and independent of observation count
- [x] merge semantics are defined and tested
- [x] deterministic behavior is tested on every supported MoonBit target
- [x] repeated equal values, sparse distributions, and extreme values are covered
- [x] snapshot/report APIs expose percentiles without retaining raw samples
- [x] overhead benchmark compares M1 against the M0 aggregate path

## Evidence

PR #2: `feat: add bounded distribution statistics`

Toolchain:

- MoonBit `0.1.20260920`

CI run #15:

- `moon fmt --check` — PASS
- `moon check --target all` — PASS
- `moon test --target all` — PASS
  - wasm: 10/10
  - wasm-gc: 10/10
  - js: 10/10
  - native: 10/10
- `moon bench --target native` — PASS
  - M0 aggregate-only: 5.33 ns ± 0.06 ns
  - M1 bounded histogram: 7.58 ns ± 0.53 ns
  - 10 × 100000 runs for each benchmark

The benchmark uses equivalent label lookup, duration clamping, and aggregate update paths in M0 and M1; the M1 path additionally maintains the bounded histogram. It is a relative micro-benchmark intended to make distribution overhead visible in CI, not a cross-machine performance guarantee.

## Follow-up

The next roadmap milestone is M2 source instrumentation.
