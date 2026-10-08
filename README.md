# hotpath.mbt

MoonBit-first application profiling toolkit inspired by [pawurb/hotpath-rs](https://github.com/pawurb/hotpath-rs).

The runtime provides portable explicit scoped timing, deterministic aggregation, bounded distribution statistics, snapshots, merge/reset hooks, and text reports. CPU/allocation sampling is intentionally left to profilers such as `moon-pprof`; future hotpath.mbt tooling will correlate those samples with application-level instrumentation.

## Installation

Add version 0.1.0 of the module:

```sh
moon add f4ah6o/hotpath@0.1.0
```

Import the `src` package in the consuming package's `moon.pkg`:

```moonbit
import {
  "f4ah6o/hotpath/src" @hotpath,
}
```

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

### Opt-in nanosecond measurements

For sub-millisecond application spans, use the separate `ProfilerNs` facade.
The original `Profiler`, millisecond fields and report format are unchanged.

```moonbit nocheck
let profiler = @hotpath.ProfilerNs::new()
let value = profiler.measure_ns_with("input.handle", monotonic_now_ns, () => work())
println(profiler.render_text())
```

The caller must supply nonnegative monotonic nanosecond timestamps, check its
actual clock resolution, and bound the label vocabulary. Nanoseconds are the
storage unit; this API does not promise nanosecond clock accuracy or resolution.
Backward/invalid clocks omit samples and increment `invalid_clock_samples`.
`record_ns` rejects negative values. Totals saturate at Int64 maximum with an
explicit `total_saturated` flag; excess calls at Int maximum are dropped and
reported by `dropped_samples`. Reset clears data and diagnostics. Histogram
percentiles remain bounded estimates. `ProfilerNs` is synchronous, not
thread-safe, and does not retain raw samples, install a clock or subtract its
instrumentation overhead. Capture bounded raw samples in the calling harness
and measure that overhead separately when evaluating a regression.

Each label also owns a fixed 64-counter logarithmic histogram. Distribution memory is therefore bounded independently of observation count. `p50_ms`, `p95_ms`, and `p99_ms` are deterministic bucket estimates capped by the observed maximum; raw samples are never retained. `Profiler::merge` combines both aggregate counters and histogram buckets while preserving deterministic label order.

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

Not yet implemented: source rewriting for `#hotpath.measure`, CPU/allocation correlation, JSON/Prometheus, CI regression policy, MCP, and HTTP/I/O/channel/lock adapters. These are tracked as repository-local design packets under `issues/`; GitHub Issues are intentionally not used.

## Terminal report example

The current text output is a compact, deterministic, tab-separated snapshot from `Profiler::render_text()`. It is not an interactive hotpath-rs-style terminal dashboard: there is no live TUI, CPU/allocation sampler, thread view, or boxed table yet.

Run a small example that prints the existing public API's report:

```sh
moon run --target native examples/terminal_report -q
```

The example feeds fixed synthetic millisecond durations through `record_ms`, so its output is reproducible and illustrative only; it is not a measurement of the example's execution time. The `p50_ms`, `p95_ms`, and `p99_ms` columns are bounded estimates from the fixed logarithmic histogram. Raw observations are not retained, so these are not exact percentiles computed from a stored sample list.

The screenshot below is an unedited capture of the cloud terminal window running this command. Only terminal tab stops were adjusted for readability (`tabs 12,20,31,40,49,58,67,76,85`); the rendered report headers and values are unchanged.

![Terminal output from the reproducible report example](docs/images/terminal-report.jpg)

## Development

```sh
moon check --target all
moon test --target all
moon bench --target native
moon fmt --check
```

Issue packets move through `issues/open/`, `issues/polished/`, and `issues/done/`. See `issues/polished/0002-production-roadmap.md` for the production-ready roadmap.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).

## Patch release from `latest`

Move the `latest` tag to the current `main` commit and push it:

```sh
git switch main
git pull --ff-only origin main
git tag -f latest HEAD
git push --force origin refs/tags/latest
```

The `latest` event runs the patch version bump, updates `moon.mod` (and
the CLI version constant, when present), atomically pushes the version
commit with a fixed `vX.Y.Z` tag, builds Linux x64/ARM64 and macOS ARM64
assets, and publishes the versioned GitHub Release. `latest` is a trigger,
not a Release tag.

The workflow refuses stale main/tag targets or an existing version tag,
and rerunning the same failed release reuses its tagged version commit.
The token must be allowed to push to `main`; branch protection is not
bypassed. Direct `vX.Y.Z` tag pushes are still supported when the tag
matches the version recorded in `moon.mod`.

