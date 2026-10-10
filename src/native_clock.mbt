///|
#cfg(all(target="native", not(platform="windows")))
extern "C" fn native_clock_now_ns() -> Int64 = "hotpath_native_clock_now_ns"

///|
#cfg(all(target="native", not(platform="windows")))
extern "C" fn native_clock_get_resolution_ns() -> Int64 = "hotpath_native_clock_resolution_ns"

///|
/// Return the resolution reported for the native monotonic clock, in
/// nanoseconds. A negative result means the platform clock could not be read.
///
/// This is the operating system's advertised resolution, not a promise that
/// every measurement changes by that amount.
#cfg(all(target="native", not(platform="windows")))
pub fn native_clock_resolution_ns() -> Int64 {
  native_clock_get_resolution_ns()
}

///|
/// Measure a closure with the native monotonic clock on POSIX targets.
///
/// The clock has an arbitrary origin and is independent of wall-clock changes.
/// If either clock read fails, the closure still returns normally and the
/// profiler records an invalid clock sample instead of inventing a duration.
#cfg(all(target="native", not(platform="windows")))
pub fn[T] ProfilerNs::measure_native_ns(
  self : ProfilerNs,
  label : String,
  body : () -> T,
) -> T {
  self.measure_ns_with(label, () => native_clock_now_ns(), body)
}
