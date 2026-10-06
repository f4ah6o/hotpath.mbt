# Nanosecond-unit application spans

GPUI's local input/composition workload needs spans below one millisecond.
At upstream be4cb98a3eb61bd5ab176c9e5e6bd921b74d1dce the public profiler
accepts integer milliseconds only, including its injected-clock API. Supplying
nanoseconds to `measure_with` would incorrectly label all aggregates as ms.

Additive resolution: `ProfilerNs`, `MeasurementNs`, `record_ns` and
`measure_ns_with`. Existing millisecond behavior and storage stay unchanged.
The caller owns the monotonic adapter and bounded raw samples. Invalid clocks,
duration/counter overflow and saturation are explicit. Reuse existing fixed
histogram math without changing the old API or its report format.

Tests cover 123ns, closure results, backward and failed clocks, Int64 timestamp
limits, saturated totals, count exhaustion, nested spans, reset, and fixed
histogram capacity. Native clock adapters, thread safety, merge, sampling and
regression policies are outside this minimal facade.
