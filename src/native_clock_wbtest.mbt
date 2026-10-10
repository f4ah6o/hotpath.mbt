///|
#cfg(target="native")
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
#cfg(target="native")
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

///|
#cfg(all(target="native", platform="windows"))
extern "C" fn windows_ticks_to_ns(ticks : Int64, frequency : Int64) -> Int64 = "hotpath_windows_ticks_to_ns"

///|
#cfg(all(target="native", platform="windows"))
extern "C" fn windows_resolution_ns(frequency : Int64) -> Int64 = "hotpath_windows_resolution_ns"

///|
#cfg(all(target="native", platform="windows"))
test "Windows counter conversion is exact at ordinary and wide bounds" {
  assert_eq(windows_ticks_to_ns(1L, 3L), 333333333L)
  assert_eq(windows_ticks_to_ns(2L, 3L), 666666666L)
  assert_eq(windows_ticks_to_ns(3L, 3L), 1000000000L)
  assert_eq(
    windows_ticks_to_ns(9223372036854775806L, 9223372036854775807L),
    999999999L,
  )
  assert_eq(windows_ticks_to_ns(9223372036854775807L, 1L), -1L)
  assert_eq(windows_ticks_to_ns(-1L, 10L), -1L)
  assert_eq(windows_ticks_to_ns(1L, 0L), -1L)
}

///|
#cfg(all(target="native", platform="windows"))
test "Windows counter resolution rounds up to integral nanoseconds" {
  assert_eq(windows_resolution_ns(3L), 333333334L)
  assert_eq(windows_resolution_ns(1000000001L), 1L)
  assert_eq(windows_resolution_ns(0L), -1L)
}
