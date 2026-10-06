# 0006 — Apple Silicon macOS runtime and support qualification

Status: open
Date: 2026-10-07 (JST)
Parent: [0002 — Production-ready roadmap](../polished/0002-production-roadmap.md)
Milestones: M3 macOS clock/runtime integration; M9 macOS qualification

## Goal

Qualify macOS on Apple Silicon with native arm64 execution. Intel/x86_64 macOS, universal binaries, and Rosetta compatibility are outside scope.

## Current boundary

At `87a8d8494d5e2c2b4fed2115882315ba652dc37c`, millisecond profiling and injected-clock `ProfilerNs` are implemented. There is no macOS native clock adapter or macOS CI job. Nanosecond storage does not establish clock accuracy or Apple Silicon qualification.

## Scope and dependencies

Use the parent's shared M3 timing/finalization contract and M9 release policy. Common implementation stays in 0002; completed histogram/nanosecond packets 0003/0004 are not reopened.

## Acceptance

- [ ] List qualified macOS versions, Apple Silicon arm64 host/execution architecture, MoonBit toolchains, targets, and runtimes; explicitly exclude Intel/x86_64 and Rosetta.
- [ ] Document the native clock source, measured resolution, monotonicity, and suspend/resume behavior; test nanosecond conversion, overflow, clock failure, and explicit fallback/unsupported behavior.
- [ ] Keep macOS types inside the adapter. Preserve existing millisecond APIs/reports and caller-supplied nanosecond clocks.
- [ ] Run format/check/tests on verified Apple Silicon arm64 hosts for each claimed combination, recording host, toolchain, commands, and results. A macOS runner label alone is insufficient architecture evidence.
- [ ] Verify macOS-specific error/unwind/shutdown behavior against the agreed M3 contract and record cleanup limitations. Async/cancellation guarantees require the parent's shared design first.
- [ ] Run existing overhead benchmarks and bounded-label stress checks natively on arm64; measure native-clock overhead separately. Apply the parent's concurrency model; do not imply `ProfilerNs` is thread-safe.
- [ ] Link qualification evidence from the README/support matrix, including remaining limitations and the Apple Silicon-only policy.

## Completion boundary

Apple Silicon macOS evidence contributes to M3/M9; this packet alone does not complete either milestone or establish production readiness.
