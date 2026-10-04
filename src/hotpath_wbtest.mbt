///|
test "repeated labels aggregate" {
  let profiler = Profiler::new()
  profiler.record_ms("parse", 10L)
  profiler.record_ms("parse", 20L)
  let rows = profiler.snapshot()
  inspect(rows.length(), content="1")
  inspect(rows[0].label, content="parse")
  inspect(rows[0].calls, content="2")
  inspect(rows[0].total_ms, content="30")
  inspect(rows[0].average_ms, content="15")
  inspect(rows[0].min_ms, content="10")
  inspect(rows[0].max_ms, content="20")
}

///|
test "negative and zero durations are safe" {
  let profiler = Profiler::new()
  profiler.record_ms("clock", -5L)
  profiler.record_ms("clock", 0L)
  let row = profiler.snapshot()[0]
  inspect(row.calls, content="2")
  inspect(row.total_ms, content="0")
  inspect(row.min_ms, content="0")
  inspect(row.max_ms, content="0")
}

///|
test "nested measurements aggregate independently" {
  let profiler = Profiler::new()
  let tick = Ref::new(0L)
  let now = fn() {
    let current = tick.val
    tick.val = current + 10L
    current
  }
  profiler.measure_with("outer", now, fn() {
    profiler.measure_with("inner", now, fn() { () })
  })
  let rows = profiler.snapshot()
  inspect(rows.length(), content="2")
  inspect(rows[0].label, content="inner")
  inspect(rows[0].total_ms, content="10")
  inspect(rows[1].label, content="outer")
  inspect(rows[1].total_ms, content="30")
}

///|
test "reset clears state" {
  let profiler = Profiler::new()
  profiler.record_ms("one", 1L)
  profiler.reset()
  inspect(profiler.snapshot().length(), content="0")
}

///|
test "snapshot and report order are deterministic" {
  let profiler = Profiler::new()
  profiler.record_ms("beta", 2L)
  profiler.record_ms("alpha", 1L)
  profiler.record_ms("beta", 4L)
  let rows = profiler.snapshot()
  inspect(rows[0].label, content="beta")
  inspect(rows[1].label, content="alpha")
  inspect(
    profiler.render_text(),
    content="hotpath.mbt\nlabel\tcalls\ttotal_ms\tavg_ms\tmin_ms\tmax_ms\nbeta\t2\t6\t3\t2\t4\nalpha\t1\t1\t1\t1\t1\n",
  )
}
