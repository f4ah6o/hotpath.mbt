///|
priv struct BaselineAggregate {
  mut calls : Int
  mut total_ms : Int64
  mut min_ms : Int64
  mut max_ms : Int64
}

///|
fn BaselineAggregate::new() -> BaselineAggregate {
  { calls: 0, total_ms: 0L, min_ms: 0L, max_ms: 0L }
}

///|
fn BaselineAggregate::record(self : BaselineAggregate, elapsed_ms : Int64) -> Unit {
  if self.calls == 0 {
    self.calls = 1
    self.total_ms = elapsed_ms
    self.min_ms = elapsed_ms
    self.max_ms = elapsed_ms
    return
  }
  self.calls = self.calls + 1
  self.total_ms = self.total_ms + elapsed_ms
  if elapsed_ms < self.min_ms {
    self.min_ms = elapsed_ms
  }
  if elapsed_ms > self.max_ms {
    self.max_ms = elapsed_ms
  }
}

///|
test (b : @bench.T) {
  let baseline = BaselineAggregate::new()
  b.bench(name="m0_aggregate_only", fn() { baseline.record(10L) })
  let profiler = Profiler::new()
  b.bench(name="m1_bounded_histogram", fn() { profiler.record_ms("parse", 10L) })
}
