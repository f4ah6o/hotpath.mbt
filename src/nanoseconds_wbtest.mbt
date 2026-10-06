///|
test "ns samples preserve sub millisecond durations and return values" {
  let p = ProfilerNs::new()
  let tick = Ref(10L)
  let result = p.measure_ns_with(
    "sub-ms",
    fn() {
      let value = tick.val
      tick.val += 123L
      value
    },
    () => 42,
  )
  assert_eq(result, 42)
  let row = p.snapshot()[0]
  assert_eq(row.total_ns, 123L)
  assert_eq(row.calls, 1)
  assert_eq(row.p95_ns, 123L)
  assert_false(row.total_saturated)
  p.record_ns("sub-ms", 1L)
  assert_eq(p.snapshot()[0].average_ns, 62L)
}

///|
test "backward and invalid clocks do not invent zero durations" {
  let p = ProfilerNs::new()
  for times in [[20L, 10L], [-1L, 1L], [1L, -1L]] {
    let index = Ref(0)
    assert_eq(
      p.measure_ns_with(
        "bad",
        fn() {
          let value = times[index.val]
          index.val += 1
          value
        },
        () => 7,
      ),
      7,
    )
  }
  assert_eq(p.invalid_clock_samples(), 3)
  assert_eq(p.snapshot().length(), 0)
  p.record_ns("bad", -1L)
  assert_eq(p.invalid_clock_samples(), 4)
}

///|
test "ns totals saturate explicitly and maximum timestamps subtract safely" {
  let p = ProfilerNs::new()
  let index = Ref(0)
  let times = [0L, 9223372036854775807L]
  p.measure_ns_with(
    "wide",
    fn() {
      let value = times[index.val]
      index.val += 1
      value
    },
    () => (),
  )
  p.record_ns("wide", 1L)
  assert_eq(p.snapshot()[0].total_ns, 9223372036854775807L)
  assert_true(p.snapshot()[0].total_saturated)
  assert_eq(p.snapshot()[0].p99_ns, 9223372036854775807L)
}

///|
test "ns count overflow drops samples and reset clears diagnostics" {
  let p = ProfilerNs::new()
  p.record_ns("full", 1L)
  p.entries[0].calls = 2147483647
  p.record_ns("full", 2L)
  assert_eq(p.dropped_samples(), 1)
  assert_eq(p.snapshot()[0].max_ns, 1L)
  p.reset()
  assert_eq(p.snapshot().length(), 0)
  assert_eq(p.dropped_samples(), 0)
  assert_eq(p.invalid_clock_samples(), 0)
}

///|
test "ns nested spans and label ordering are deterministic" {
  let p = ProfilerNs::new()
  let tick = Ref(0L)
  let now = fn() {
    let value = tick.val
    tick.val += 11L
    value
  }
  p.measure_ns_with("outer", now, () => {
    p.measure_ns_with("inner", now, () => ())
  })
  assert_eq(p.snapshot()[0].label, "inner")
  assert_eq(p.snapshot()[0].total_ns, 11L)
  assert_eq(p.snapshot()[1].total_ns, 33L)
  assert_eq(p.entries[0].buckets.length(), 64)
  p.record_ns("a\tb\n", 0L)
  assert_true(p.render_text().contains("a\\tb\\n\t1\t0"))
}
