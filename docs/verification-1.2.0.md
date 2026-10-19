# STIX System 1.2.0 (build 7) — 2026-10-19

## Behavior

Corrected the former active-page-only used-memory estimate. Physical used RAM now includes resident anonymous pages (minus bounded purgeable pages), wired pages and compressor pages. Available RAM is total minus this used estimate; cached file-backed/purgeable memory is a subset of available, bounded to that capacity. The compressor's original uncompressed size is never treated as physical capacity. Availability is explicitly described as an estimate, not guaranteed immediate allocation or an exact reproduction of Activity Monitor's private accounting.

Panel additions are two small rows: available/cache, and swap read/write activity. Existing pressure now has an explicit green/orange/red indicator; Swap and Compressed stay on one row. The user explicitly chose swap MB/s instead of an inferred overall responsiveness rating.

Swap rates use differences of cumulative `swapins`/`swapouts` pages over monotonic time, multiplied by the page size. This is logical page throughput, not physical compressed SSD write throughput or application latency. First/reset/stale (>10s) intervals show unavailable; idle intervals show zero.

## Validation

- 34 XCTest tests pass, zero failures. Fixtures verify cache remains available, compressor remains used, inconsistent counters stay bounded, positive read/write rates, first-sample unavailability, reset/long-gap suppression and zero activity.
- Debug diagnostic sampled: used 23033282560 bytes, available 2736521216, cached 1974829056, compressed 4035330048, total 25769803776. Sum/bounds invariants passed. Adjacent live vm_stat produced used 21.494 GB, available 2.506 GB, cache 1.811 GB; modest differences between successive snapshots occurred during active workload. Pressure sysctl=1 matched sampled pressure=1.
- A live nonzero logical swap read rate (1160619 bytes/s) was observed; no artificial memory stress was generated.
- Release build succeeded, installed app/helper signed with existing Developer ID and strictly verified; daemon registration enabled (status 1).
- Native accessibility read of installed panel confirmed: used 21.38/24 GB; available 2.62 GB; cache 1.85 GB; normal pressure; Swap 8.65 GB; compressed 4.75 GB; swap read 6.99/write 0.00 MB/s. Values are live and change between samples. Screenshot capture was unavailable after the panel was dismissed; accessibility verification completed beforehand.
- Existing SwiftPM native-build-system deprecation warning remains.

Source definitions: https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/vm_statistics.h
