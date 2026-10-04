const HISTOGRAM_BUCKETS : Int = 64

///|
/// One immutable aggregate row returned by a profiler snapshot.
///
/// Percentiles are bounded-histogram estimates. Exact values are returned for
/// zero/one-millisecond buckets and the estimate is always capped by max_ms.
pub(all) struct Measurement {
  label : String
  calls : Int
  total_ms : Int64
  min_ms : Int64
  max_ms : Int64
  average_ms : Int64
  p50_ms : Int64
  p95_ms : Int64
  p99_ms : Int64
} derive(Show, Eq)

///|
struct MeasurementState {
  label : String
  mut calls : Int
  mut total_ms : Int64
  mut min_ms : Int64
  mut max_ms : Int64
  buckets : Array[Int]
}

///|
fn new_histogram() -> Array[Int] {
  let buckets : Array[Int] = []
  for _i in 0..<HISTOGRAM_BUCKETS {
    buckets.push(0)
  }
  buckets
}

///|
fn copy_histogram(source : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  for value in source {
    result.push(value)
  }
  result
}

///|
fn histogram_bucket(elapsed_ms : Int64) -> Int {
  if elapsed_ms <= 0L {
    return 0
  }
  let mut value = elapsed_ms
  let mut index = 1
  while value > 1L && index < HISTOGRAM_BUCKETS - 1 {
    value = value / 2L
    index = index + 1
  }
  index
}

///|
fn histogram_upper_bound(index : Int) -> Int64 {
  if index <= 0 {
    return 0L
  }
  let mut upper = 1L
  for _i in 1..<index {
    if upper > 4611686018427387903L {
      return 9223372036854775807L
    }
    upper = upper * 2L + 1L
  }
  upper
}

///|
fn histogram_percentile(
  buckets : Array[Int],
  calls : Int,
  percentile : Int,
  max_ms : Int64,
) -> Int64 {
  if calls <= 0 {
    return 0L
  }
  let target = (calls * percentile + 99) / 100
  let mut cumulative = 0
  for i in 0..<buckets.length() {
    cumulative = cumulative + buckets[i]
    if cumulative >= target {
      let estimate = histogram_upper_bound(i)
      return if estimate > max_ms { max_ms } else { estimate }
    }
  }
  max_ms
}

///|
/// Explicit application-level timing profiler.
///
/// Rows are kept in first-observation order so snapshots and reports are
/// deterministic without requiring a map iteration order. Each label owns a
/// fixed 64-counter logarithmic histogram, so distribution memory is bounded
/// independently of observation count.
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
  let bucket = histogram_bucket(elapsed)
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
      entry.buckets[bucket] = entry.buckets[bucket] + 1
      found = true
    }
  } nobreak {
    ()
  }
  if !found {
    let buckets = new_histogram()
    buckets[bucket] = 1
    self.entries.push({
      label,
      calls: 1,
      total_ms: elapsed,
      min_ms: elapsed,
      max_ms: elapsed,
      buckets,
    })
  }
}

///|
/// Merge another profiler into this profiler.
///
/// Aggregate counters and fixed histogram buckets are merged label-by-label.
/// Existing labels keep their original insertion order; labels seen only in
/// `other` are appended in `other`'s insertion order.
pub fn Profiler::merge(self : Profiler, other : Profiler) -> Unit {
  for source in other.entries {
    let mut found = false
    for i in 0..<self.entries.length() {
      let target = self.entries[i]
      if target.label == source.label {
        target.calls = target.calls + source.calls
        target.total_ms = target.total_ms + source.total_ms
        if source.min_ms < target.min_ms {
          target.min_ms = source.min_ms
        }
        if source.max_ms > target.max_ms {
          target.max_ms = source.max_ms
        }
        for bucket in 0..<HISTOGRAM_BUCKETS {
          target.buckets[bucket] = target.buckets[bucket] + source.buckets[bucket]
        }
        found = true
      }
    } nobreak {
      ()
    }
    if !found {
      self.entries.push({
        label: source.label,
        calls: source.calls,
        total_ms: source.total_ms,
        min_ms: source.min_ms,
        max_ms: source.max_ms,
        buckets: copy_histogram(source.buckets),
      })
    }
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
      p50_ms: histogram_percentile(
        entry.buckets,
        entry.calls,
        50,
        entry.max_ms,
      ),
      p95_ms: histogram_percentile(
        entry.buckets,
        entry.calls,
        95,
        entry.max_ms,
      ),
      p99_ms: histogram_percentile(
        entry.buckets,
        entry.calls,
        99,
        entry.max_ms,
      ),
    })
  }
  result
}

///|
fn escape_report_label(label : String) -> String {
  let sb = StringBuilder()
  for c in label {
    if c == '\\' {
      ignore(sb..write_char('\\').write_char('\\'))
    } else if c == '\t' {
      ignore(sb..write_char('\\').write_char('t'))
    } else if c == '\r' {
      ignore(sb..write_char('\\').write_char('r'))
    } else if c == '\n' {
      ignore(sb..write_char('\\').write_char('n'))
    } else {
      ignore(sb.write_char(c))
    }
  }
  sb.to_string()
}

///|
/// Render a compact deterministic text report.
///
/// Labels escape backslash, tab, carriage return, and newline so the
/// tab-separated report remains unambiguous for line-oriented consumers.
pub fn Profiler::render_text(self : Profiler) -> String {
  let mut out = "hotpath.mbt\nlabel\tcalls\ttotal_ms\tavg_ms\tmin_ms\tmax_ms\tp50_ms\tp95_ms\tp99_ms\n"
  for row in self.snapshot() {
    let label = escape_report_label(row.label)
    out = out +
      "\{label}\t\{row.calls}\t\{row.total_ms}\t\{row.average_ms}\t\{row.min_ms}\t\{row.max_ms}\t\{row.p50_ms}\t\{row.p95_ms}\t\{row.p99_ms}\n"
  }
  out
}
