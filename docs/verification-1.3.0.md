# STIX System 1.3.0 (build 9) — 2026-10-20

## Behavior

Renamed the former «ЦП» utilization heading to CPU. CPU and GPU now occupy equal columns in the existing compact header, with separate percentages and 30-sample (~one minute) sparklines. The GPU chart uses a distinct teal color.

GPU utilization comes from `IOAccelerator` registry services, `PerformanceStatistics` → `Device Utilization %`. Renderer and tiler utilization are not substituted. The sampler runs on the existing background worker every two seconds without root access or external commands. If multiple devices supply valid values, the highest utilization is displayed. Missing/invalid values show an em dash, not idle zero; unavailable history is cleared. Numeric values outside 0–100, nonfinite values and Boolean objects are rejected.

## Verification

- 39 XCTest tests passed, zero failures. Added GPU percentage/fraction, zero/100%, multi-device maximum and invalid/missing telemetry cases.
- IORegistry on this M4 Pro exposed a real Device Utilization counter. Diagnostic sampled GPU=0.62; an adjacent ioreg read showed 49%, reflecting a changing workload between samples. No synthetic GPU load was induced.
- Release built and signed with existing Developer ID; installed bundle passes strict signature verification. Installed version 1.3.0, build 9.
- Daemon re-registration initially returned transient Operation not permitted after unregister; a subsequent registration returned enabled status 1.
- Native accessibility inspection of the installed panel confirmed `CPU 36 % GPU 63 %` and distinct CPU/GPU history elements. Subsequent screenshot capture was unavailable after the panel was dismissed; no screenshot-based layout claim is made.
- Existing fan safety policy and manual handoff limitations are unchanged; no manual fan hardware test was performed for this GPU display update.
- Existing SwiftPM native-build-system deprecation warning remains.
