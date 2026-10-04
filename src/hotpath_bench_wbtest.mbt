///|
priv struct BaselineMeasurementState {
  label : String
  mut calls : Int
  mut total_ms : Int64
  mut min_ms : Int64
  mut max_ms : Int64
}

///|
priv struct BaselineProfiler {
  mut entries : Array[BaselineMeasurementState]
}

///|
fn BaselineProfiler::new() -> BaselineProfiler {
  { entries: [], }
}

///|
fn BaselineProfiler::record_ms(
  self : BaselineProfiler,
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
test (b : @bench.T) {
  let baseline = BaselineProfiler::new()
  b.bench(name="m0_aggregate_only", fn() { baseline.record_ms("parse", 10L) })
  let profiler = Profiler::new()
  b.bench(name="m1_bounded_histogram", fn() { profiler.record_ms("parse", 10L) })
}
