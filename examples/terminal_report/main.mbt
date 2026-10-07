///|
fn main {
  let profiler = @hotpath.Profiler::new()
  profiler.record_ms("parse", 2L)
  profiler.record_ms("parse", 4L)
  profiler.record_ms("parse", 8L)
  profiler.record_ms("parse", 16L)
  profiler.record_ms("layout", 1L)
  profiler.record_ms("layout", 2L)
  profiler.record_ms("layout", 4L)
  profiler.record_ms("layout", 8L)
  profiler.record_ms("render", 3L)
  profiler.record_ms("render", 6L)
  profiler.record_ms("render", 9L)
  profiler.record_ms("render", 12L)
  println("Illustrative synthetic timings only (ms)")
  println(profiler.render_text())
}
