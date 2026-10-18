# STIX System Implementation Plan

**Goal:** Deliver a runnable native menu bar monitor with real metrics, safe fan control and top-five RAM processes, tested on this Mac and published to GitHub.

**Architecture:** Swift Package with a shared SystemCore library, a SwiftUI executable and a narrow privileged fan service. A C target owns the IOKit wire ABI. Application packaging scripts produce a self-contained .app and embed the service.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Mach, libproc, IOKit, ServiceManagement, XCTest.

## Global Constraints
- macOS 14+, Russian UI, no network in application, no external packages.
- Real observations only; display unsupported data as unavailable.
- Validate all fan writes; default and failure state is automatic control.
- Keep collected process information local; publish source privately.

## Task 1 — telemetry
Files: Package.swift; Sources/SystemCore/{Models,MetricsSampler,ProcessSampler}.swift; Tests/SystemCoreTests/MetricsTests.swift.
Implement typed snapshots, host CPU deltas, memory/pressure, filesystem capacity, IOKit disk deltas, libproc RSS process ranking. Test delta resets, first-sample semantics, memory accounting and process ranking. Run swift test and a diagnostics executable against live counters.

## Task 2 — hardware and control
Files: Sources/SMCBridge/{SMCBridge.c,include/SMCBridge.h}; Sources/SystemCore/{SMC,FanPolicy,FanClient}.swift; Sources/STIXFanService/main.swift; Resources/service.plist.
Read SMC fan keys using exact ABI and validated payloads. Validate RPM against hardware bounds and a cooling-only floor. Service validates client code identity and peer user, exposes only status/automatic/manual methods, and restores firmware control after lease expiry, sleep, emergency or write failure. Test fan-policy bounds/NaN/thermal rejection and lease expiration. Verify live read-only SMC first; exercise manual control only if service authorization is available, then prove automatic restoration.

## Task 3 — application
Files: Sources/STIXSystem/{App,MonitorModel,DashboardView}.swift; Resources/Info.plist; scripts/{build,install}.sh.
Build compact MenuBarExtra panel with CPU sparkline, memory, disk, processes, thermal state and fans. Add service install/automatic/manual controls with explicit error handling, one status line and quit. Rebuild and launch installed bundle; inspect UI and compare metrics to live system observations.

## Task 4 — delivery
Files: README.md; docs/verification.md; .gitignore.
Run release build and tests, verify signatures, service packaging, live diagnostic output and UI. Record exact verified limitations. Commit focused source changes, create private repository through authenticated gh, push and verify remote SHA. Leave installed application running.
