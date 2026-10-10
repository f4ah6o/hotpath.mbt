///|
#cfg(all(target="native", not(platform="windows")))
test "native monotonic clock is ordered and reports its resolution" {
  let resolution = native_clock_resolution_ns()
  assert_true(resolution > 0L)
  let mut previous = native_clock_now_ns()
  assert_true(previous >= 0L)
  for _i in 0..<1000 {
    let current = native_clock_now_ns()
    assert_true(current >= previous)
    previous = current
  }
}

///|
#cfg(all(target="native", not(platform="windows")))
test "native monotonic measurements preserve the closure result" {
  let profiler = ProfilerNs::new()
  let result = profiler.measure_native_ns("native", () => 42)
  assert_eq(result, 42)
  let rows = profiler.snapshot()
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].label, "native")
  assert_eq(rows[0].calls, 1)
  assert_true(rows[0].total_ns >= 0L)
  assert_false(rows[0].total_saturated)
}
