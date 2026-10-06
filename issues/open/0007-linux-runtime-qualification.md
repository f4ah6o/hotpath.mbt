# 0007 — Linux runtime and support qualification

Status: open
Date: 2026-10-07 (JST)
Parent: [0002 — Production-ready roadmap](../polished/0002-production-roadmap.md)
Milestones: M3 Linux clock/runtime integration; M9 Linux qualification

## Goal

Qualify Linux-specific clocks and runtime behavior, extending the existing Ubuntu baseline only where verified.

## Current boundary

At `87a8d8494d5e2c2b4fed2115882315ba652dc37c`, millisecond profiling and injected-clock `ProfilerNs` are implemented. Ubuntu CI checks/tests all MoonBit targets and benchmarks native; its run for this commit succeeded. There is no Linux native clock adapter or explicit distro/architecture production matrix.

## Scope and dependencies

Use the parent's shared M3 timing/finalization contract and M9 release policy. Common implementation stays in 0002; completed histogram/nanosecond packets 0003/0004 are not reopened.

## Acceptance

- [ ] List qualified distro/versions, architectures, native build dependencies, MoonBit toolchains, targets, and runtimes; leave other combinations unqualified.
- [ ] Document the native clock source, measured resolution, monotonicity, and suspend/resume behavior; test nanosecond conversion, overflow, clock failure, and explicit fallback/unsupported behavior.
- [ ] Keep Linux types inside the adapter. Preserve existing millisecond APIs/reports and caller-supplied nanosecond clocks.
- [ ] Retain Ubuntu CI and extend qualification to the documented matrix, recording actual hosts, toolchains, format/check/test commands, and results. All MoonBit targets do not imply all Linux hosts.
- [ ] Verify Linux-specific error/unwind/shutdown behavior against the agreed M3 contract and record cleanup limitations. Async/cancellation guarantees require the parent's shared design first.
- [ ] Run existing overhead benchmarks and bounded-label stress checks per claimed native combination; measure native-clock overhead separately. Apply the parent's concurrency model; do not imply `ProfilerNs` is thread-safe.
- [ ] Link qualification evidence from the README/support matrix, distinguishing the existing Ubuntu baseline from additional qualified combinations.

## Completion boundary

Linux evidence contributes to M3/M9; this packet alone does not complete either milestone or establish production readiness.
