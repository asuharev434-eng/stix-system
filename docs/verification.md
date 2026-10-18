# Verification — 2026-10-18

Hardware: MacBook Pro Mac16,8, Apple M4 Pro, 24 GB RAM. OS: macOS 27.0.1. Toolchain: Xcode / Swift 6.4. Local install: `~/Applications/STIX System.app`.

## Completed

- `swift test --build-system native`: **18 tests, 0 failures**, final run 16:56 Dubai time. Includes CPU/rate calculations, counter resets, memory bounds, process ranking, fan limits, ownership, persistence-before-write, failed-write recovery/retry, lease expiry, thermal-state recovery, per-fan selection, partial Auto, Sync, separate temperature mappings, unavailable sensors, notch and external-display geometry.
- Release build succeeded without source compiler warnings; SwiftPM emits its native-backend deprecation notice.
- App and helper signed with Developer ID Application, team `9TB7MZWNXU`, hardened runtime and Apple secure timestamp. `codesign --verify --deep --strict` passed on the installed bundle.
- App and daemon launched successfully. `SMAppService` status **1 (enabled)**; launchd daemon state **running**, root service. No administrator password or signing secret is in the source tree.
- Live system measurements: CPU changes, 24 GB physical RAM, pressure, writable-volume free space, real physical-disk byte deltas, five real RAM-ranked processes, two fans with hardware limits, separate component temperatures.
- M4 Pro temperature sensors: CPU maximum from 9 available sensors, GPU maximum from 8, NAND from 1, battery maximum from 2. The three known M4 RAM-proximity keys are unavailable here and the UI correctly shows `—` for RAM temperature.
- Final live Sync smoke: targets **7126 / 7266 RPM**, observed physical RPM **7145 / 7254**, followed by both mode flags automatic and `Ftst=0`; **PASS**. Physical RPM decreases gradually after Auto, not instantaneously.
- Independent hardware test: fan 0 manual while fan 1 automatic; separate targets **6788 / 7498 RPM**; fan 0 returned to Auto while fan 1 stayed manual; renewable manual session held for **16 seconds**; last fan Auto released the global firmware handoff; **PASS**.
- Final watchdog test: manual targets **6752 / 6903 RPM**; stopped renewing while leaving the connection open; after 15 seconds both fans automatic and `Ftst=0`; **PASS**.
- Native UI inspected through accessibility and screenshot. All five process rows, component temperatures, two independent fan controls and Sync visible. Sync was toggled on and the controls collapsed to one common setting. Final reopened UI defaults to independent controls with both fans in Auto.
- Panel no longer uses automatic popover placement. It is bounded by `visibleFrame` and the display's top safe inset; viewport scrolls on short screens. Native window screenshot confirms the complete panel is visible. Geometry tests cover notched and short secondary displays.
- Shell scripts passed `bash -n`; source changes passed `git diff --check`.

Installed main executable SHA-256:

```
bfc607e50229b013427da18aa41bd405cd7776cdc48720cbc6c1c92ba94ae663
```

## Limits of verification

Physical sleep/wake, forced root-daemon crash recovery, hostile XPC clients, and other Mac models have not been exercised on hardware. Their handling is implemented and the recovery controller is unit-tested. No claim of notarization or App Store submission is made. The closed AppleSMC interface and sensor identities require regression checks after OS/firmware changes. The running application only collects data locally; raw process snapshots used during verification remain outside the repository.
