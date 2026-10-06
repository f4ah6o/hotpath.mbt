///|
/// Nanosecond-unit aggregate. Percentiles are logarithmic bucket estimates,
/// not exact quantiles. The unit does not imply clock resolution.
pub(all) struct MeasurementNs {
  label : String
  calls : Int
  total_ns : Int64
  min_ns : Int64
  max_ns : Int64
  average_ns : Int64
  p50_ns : Int64
  p95_ns : Int64
  p99_ns : Int64
  total_saturated : Bool
} derive(Eq)

///|
pub extend MeasurementNs with Eq::{equal, not_equal}

///|
struct StateNs {
  label : String
  mut calls : Int
  mut total : Int64
  mut minimum : Int64
  mut maximum : Int64
  mut saturated : Bool
  buckets : Array[Int]
}

///|
/// Explicit high-resolution facade, separate from the unchanged ms API.
/// Callers supply nonnegative monotonic timestamps. No wall clock is assumed.
/// Per-label distribution storage is bounded to64 counters; raw samples are
/// the caller's responsibility. This profiler is synchronous, not thread-safe.
pub struct ProfilerNs {
  priv mut entries : Array[StateNs]
  priv mut invalid_clocks : Int
  priv mut dropped : Int
}

///|
pub fn ProfilerNs::new() -> ProfilerNs {
  { entries: [], invalid_clocks: 0, dropped: 0, }
}

///|
pub fn ProfilerNs::reset(self : ProfilerNs) -> Unit {
  self.entries = []
  self.invalid_clocks = 0
  self.dropped = 0
}

///|
pub fn ProfilerNs::invalid_clock_samples(self : ProfilerNs) -> Int {
  self.invalid_clocks
}

///|
pub fn ProfilerNs::dropped_samples(self : ProfilerNs) -> Int {
  self.dropped
}

///|
/// Record a duration. Negative values are rejected. Counts cannot wrap;
/// excess samples are dropped and reported. Totals saturate and flag overflow.
pub fn ProfilerNs::record_ns(
  self : ProfilerNs,
  label : String,
  elapsed_ns : Int64,
) -> Unit {
  if elapsed_ns < 0L {
    if self.invalid_clocks < 2147483647 {
      self.invalid_clocks += 1
    }
    return
  }
  let bucket = histogram_bucket(elapsed_ns)
  for entry in self.entries {
    if entry.label == label {
      if entry.calls == 2147483647 {
        if self.dropped < 2147483647 {
          self.dropped += 1
        }
        return
      }
      entry.calls += 1
      if elapsed_ns > 9223372036854775807L - entry.total {
        entry.total = 9223372036854775807L
        entry.saturated = true
      } else {
        entry.total += elapsed_ns
      }
      if elapsed_ns < entry.minimum {
        entry.minimum = elapsed_ns
      }
      if elapsed_ns > entry.maximum {
        entry.maximum = elapsed_ns
      }
      entry.buckets[bucket] += 1
      return
    }
  }
  let buckets = new_histogram()
  buckets[bucket] = 1
  self.entries.push({
    label,
    calls: 1,
    total: elapsed_ns,
    minimum: elapsed_ns,
    maximum: elapsed_ns,
    saturated: false,
    buckets,
  })
}

///|
/// Measure with an injected monotonic nanosecond clock. Invalid/backward
/// timestamps omit the timing sample but preserve the closure's return value.
/// Nonnegative ordered timestamps guarantee subtraction cannot overflow.
pub fn[T] ProfilerNs::measure_ns_with(
  self : ProfilerNs,
  label : String,
  now_ns : () -> Int64,
  body : () -> T,
) -> T {
  let started = now_ns()
  let result = body()
  let finished = now_ns()
  if started < 0L || finished < started {
    if self.invalid_clocks < 2147483647 {
      self.invalid_clocks += 1
    }
  } else {
    self.record_ns(label, finished - started)
  }
  result
}

///|
pub fn ProfilerNs::snapshot(self : ProfilerNs) -> Array[MeasurementNs] {
  self.entries.map(entry => {
    label: entry.label,
    calls: entry.calls,
    total_ns: entry.total,
    min_ns: entry.minimum,
    max_ns: entry.maximum,
    average_ns: entry.total / entry.calls.to_int64(),
    p50_ns: histogram_percentile(entry.buckets, entry.calls, 50, entry.maximum),
    p95_ns: histogram_percentile(entry.buckets, entry.calls, 95, entry.maximum),
    p99_ns: histogram_percentile(entry.buckets, entry.calls, 99, entry.maximum),
    total_saturated: entry.saturated,
  })
}

///|
pub fn ProfilerNs::render_text(self : ProfilerNs) -> String {
  let out = StringBuilder()
  out.write_string(
    "hotpath.mbt ns\nlabel\tcalls\ttotal_ns\tavg_ns\tmin_ns\tmax_ns\tp50_ns\tp95_ns\tp99_ns\ttotal_saturated\n",
  )
  |> ignore
  for row in self.snapshot() {
    let label = escape_report_label(row.label)
    out.write_string(
      "\{label}\t\{row.calls}\t\{row.total_ns}\t\{row.average_ns}\t\{row.min_ns}\t\{row.max_ns}\t\{row.p50_ns}\t\{row.p95_ns}\t\{row.p99_ns}\t\{row.total_saturated}\n",
    )
    |> ignore
  }
  out.to_string()
}
