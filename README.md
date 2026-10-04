# hotpath.mbt

MoonBit-first application profiling toolkit inspired by [pawurb/hotpath-rs](https://github.com/pawurb/hotpath-rs).

The first slice provides a small, portable runtime for explicit scoped timing, deterministic aggregation, snapshots, reset hooks, and text reports. CPU/allocation sampling is intentionally left to profilers such as `moon-pprof`; future hotpath.mbt tooling will correlate those samples with application-level instrumentation.

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

Durations are currently stored in milliseconds. The default clock uses `moonbitlang/core/env`. The aggregation core is clock-independent, so later target-specific monotonic/high-resolution adapters do not change the report model.

## Current scope

- explicit scoped timing via `Profiler::measure`
- injectable clock via `Profiler::measure_with`
- repeated-label aggregation
- nested measurements
- calls / total / min / max / integer average
- stable insertion-order snapshots and text reports
- deterministic reset/test hooks

Not yet implemented: source rewriting for `#hotpath.measure`, bounded percentiles, CPU/allocation correlation, JSON/Prometheus, CI regression policy, MCP, and HTTP/I/O/channel/lock adapters. These are tracked as repository-local design packets under `issues/open/`; GitHub Issues are intentionally not used.

## Development

```sh
moon check --target all
moon test --target all
moon fmt --check
```

See `issues/open/` for architecture and milestone design.
