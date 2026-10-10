# Changes

## Unreleased

## [0.2.1] - 2026-10-10

### Added

- Native Windows monotonic nanosecond timing through QueryPerformanceCounter,
  with overflow-safe tick conversion and a reported integral-nanosecond resolution.
- Windows-native clock, boundary-conversion, and benchmark coverage.

### Changed

- Extend native clock availability to Windows while keeping POSIX clock behavior unchanged.

## [0.2.0] - 2026-10-10

### Added

- Native POSIX monotonic nanosecond timing through `ProfilerNs::measure_native_ns` and `native_clock_resolution_ns()`.
- Native macOS CI coverage and benchmarks for the clock read and complete nanosecond measurement path.

### Changed

- Verify that the macOS CI and release runners are Apple Silicon before qualifying or packaging the Darwin artifact.
