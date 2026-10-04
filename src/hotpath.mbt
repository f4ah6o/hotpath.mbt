///|
/// One immutable aggregate row returned by a profiler snapshot.
pub(all) struct Measurement {
  label : String
  calls : Int
  total_ms : Int64
  min_ms : Int64
  max_ms : Int64
  average_ms : Int64
} derive(Show, Eq)

///|
struct MeasurementState {
  label : String
  mut calls : Int
  mut total_ms : Int64
  mut min_ms : Int64
  mut max_ms : Int64
}

///|
/// Explicit application-level timing profiler.
///
/// Rows are kept in first-observation order so snapshots and reports are
/// deterministic without requiring a map iteration order.
pub struct Profiler {
  priv mut entries : Array[MeasurementState]
}

///|
pub fn Profiler::new() -> Profiler {
  { entries: [], }
}

///|
/// Remove all recorded measurements.
pub fn Profiler::reset(self : Profiler) -> Unit {
  self.entries = []
}

///|
/// Record one completed measurement.
///
/// Negative durations are clamped to zero. This keeps clock adjustments or a
/// buggy injected test clock from corrupting aggregates.
pub fn Profiler::record_ms(
  self : Profiler,
  label : String,
  elapsed_ms : Int64,
) -> Unit {
  let elapsed = if elapsed_ms < 0L { 0L } else { elapsed_ms }
  let mut found = false
  for i in 0..<self.entries.length() {
    let entry = self.entries[i]
    if entry.label == label {
      entry.calls = entry.calls + 1
      entry.total_ms = entry.total_ms + elapsed
      if elapsed < entry.min_ms {
        entry.min_ms = elapsed
      }
      if elapsed > entry.max_ms {
        entry.max_ms = elapsed
      }
      found = true
    }
  } nobreak {
    ()
  }
  if !found {
    self.entries.push({
      label,
      calls: 1,
      total_ms: elapsed,
      min_ms: elapsed,
      max_ms: elapsed,
    })
  }
}

///|
/// Measure a closure with a caller-provided clock that returns milliseconds.
///
/// Clock injection isolates aggregation from platform clock details and makes
/// deterministic tests possible.
pub fn[T] Profiler::measure_with(
  self : Profiler,
  label : String,
  now_ms : () -> Int64,
  body : () -> T,
) -> T {
  let started = now_ms()
  let result = body()
  let finished = now_ms()
  self.record_ms(label, finished - started)
  result
}

///|
/// Measure a closure using MoonBit's portable environment clock.
pub fn[T] Profiler::measure(
  self : Profiler,
  label : String,
  body : () -> T,
) -> T {
  self.measure_with(label, fn() { @env.now().reinterpret_as_int64() }, body)
}

///|
/// Return an immutable snapshot in deterministic first-observation order.
pub fn Profiler::snapshot(self : Profiler) -> Array[Measurement] {
  let result : Array[Measurement] = []
  for entry in self.entries {
    let average = if entry.calls == 0 {
      0L
    } else {
      entry.total_ms / entry.calls.to_int64()
    }
    result.push({
      label: entry.label,
      calls: entry.calls,
      total_ms: entry.total_ms,
      min_ms: entry.min_ms,
      max_ms: entry.max_ms,
      average_ms: average,
    })
  }
  result
}

///|
/// Render a compact deterministic text report.
pub fn Profiler::render_text(self : Profiler) -> String {
  let mut out = "hotpath.mbt\nlabel\tcalls\ttotal_ms\tavg_ms\tmin_ms\tmax_ms\n"
  for row in self.snapshot() {
    out = out +
      "\{row.label}\t\{row.calls}\t\{row.total_ms}\t\{row.average_ms}\t\{row.min_ms}\t\{row.max_ms}\n"
  }
  out
}
