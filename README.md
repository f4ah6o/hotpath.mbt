# hotpath.mbt

MoonBit-first application profiling toolkit inspired by [pawurb/hotpath-rs](https://github.com/pawurb/hotpath-rs).

The runtime provides portable explicit scoped timing, deterministic aggregation, bounded distribution statistics, snapshots, merge/reset hooks, and text reports. CPU/allocation sampling is intentionally left to profilers such as `moon-pprof`; future hotpath.mbt tooling will correlate those samples with application-level instrumentation.

## Quick start

```moonbit
let profiler = @hotpath.Profiler::new()

let value = profiler.measure("parse", fn() {
  // work
  42
})

profiler.measure("render", fn() {
  // more work
  ()
}) |> ignore

println(profiler.render_text())
```

For deterministic tests or a target-specific high-resolution clock, inject a clock:

```moonbit
let tick = Ref::new(0L)
let now = fn() {
  let current = tick.val
  tick.val = current + 10L
  current
}

profiler.measure_with("fake", now, fn() { () }) |> ignore
```

Durations are currently stored in milliseconds. The default clock uses `moonbitlang/core/env`. The aggregation core is clock-independent, so later target-specific monotonic/high-resolution adapters do not change the aggregate model.

Each label also owns a fixed 64-counter logarithmic histogram. Distribution memory is therefore bounded independently of observation count. `p50_ms`, `p95_ms`, and `p99_ms` are deterministic bucket estimates capped by the observed maximum; raw samples are never retained. `Profiler::merge` combines both aggregate counters and histogram buckets while preserving deterministic label order.

## Source instrumentation (M2)

Canonical MoonBit sources can opt in with the compiler-ignored user attribute:

```moonbit
#hotpath.measure
fn parse(input : String) -> Result {
  // work
}
```

An explicit label is optional: `#hotpath.measure("parser")`. A default label is derived from the function name. Use `#hotpath.measure(skip=true)` as an escape hatch for a declaration that must stay uninstrumented.

MoonBit attributes do not target arbitrary local blocks, so explicit block measurement uses a comment directive immediately before an explicit block:

```moonbit
// #hotpath.measure("decode")
{
  // measured block
}
```

Generate a non-destructive build view and build it with:

```sh
python3 hotpath view .
python3 hotpath build . -- --target native
python3 hotpath clean .
```

The generated tree is always `.hotpath/build-view`. Every `view`/`build` run deletes and recreates that directory, canonical files are never edited, and only generated package metadata receives the `@hotpath` runtime import. Downstream modules must declare the runtime dependency first with `moon add f4ah6o/hotpath`.

M2 intentionally fails closed for unsupported source forms. In particular, annotated async functions report an original-source diagnostic and require `skip=true` until M3 defines async/cancellation finalization. Rewriting preserves source line count so diagnostics from generated builds retain useful original line locations.

## Current scope

- explicit scoped timing via `Profiler::measure`
- injectable clock via `Profiler::measure_with`
- repeated-label aggregation
- nested measurements
- calls / total / min / max / integer average
- bounded p50 / p95 / p99 estimates
- deterministic profiler merge
- stable insertion-order snapshots and text reports
- deterministic reset/test hooks
- M0-vs-M1 native micro-benchmark in CI
- opt-in `#hotpath.measure` function rewriting
- explicit measured block directives
- deterministic non-destructive `.hotpath/build-view`
- `view` / `build` / `clean` host command

Not yet implemented: async/raise finalization, CPU/allocation correlation, JSON/Prometheus, CI regression policy, MCP, and HTTP/I/O/channel/lock adapters. These are tracked as repository-local design packets under `issues/`; GitHub Issues are intentionally not used.

## Development

```sh
moon check --target all
moon test --target all
moon bench --target native
moon fmt --check
python3 -m unittest discover -s tests -p 'test_*.py'
python3 hotpath view .
```

Issue packets move through `issues/open/`, `issues/polished/`, and `issues/done/`. See `issues/polished/0002-production-roadmap.md` for the production-ready roadmap.
