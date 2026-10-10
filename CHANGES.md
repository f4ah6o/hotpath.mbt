# Changes

## Unreleased

## [0.2.0] - 2026-10-10

### Added

- Native POSIX monotonic nanosecond timing through `ProfilerNs::measure_native_ns` and `native_clock_resolution_ns()`.
- Native macOS CI coverage and benchmarks for the clock read and complete nanosecond measurement path.

### Changed

- Verify that the macOS CI and release runners are Apple Silicon before qualifying or packaging the Darwin artifact.
