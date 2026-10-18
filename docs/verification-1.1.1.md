# STIX System 1.1.1 (build 3) — 2026-10-18

## Change

Removed session baseline/current RPM and software 2000 RPM floor from privileged policy and SwiftUI bounds. Both units use the SMC minimum–maximum range; Sync RPM uses its intersection across fans. Added CPU/GPU ≥95 °C protection before/after writes, on renewal and the existing one-second watchdog, alongside OS serious/critical protection. This is an application threshold, not an Apple temperature specification. Sleep, connection loss, lease and crash recovery remain enabled.

## Verification on this Mac

- 30 XCTest tests passed. New regression tests first failed against the previous policy: a 1200 RPM hardware minimum was clamped to current 3000 RPM; CPU/GPU temperature protection was missing while thermal state was nominal. Tests now cover accepting that minimum, rejecting values outside hardware bounds, hot CPU rejection and hot GPU recovery via renewal/watchdog.
- Release app and helper signed with the existing Developer ID; installed bundle passes `codesign --verify --deep --strict`.
- Installed at `~/Applications/STIX System.app`; previous bundle retained by installer in Application Support backups. Fan daemon re-registered, status enabled, launchctl running.
- Installed binary `--fan-range-test` passed. SMC ranges: fan 0 and 1 both 2317–7826 RPM. Starting physical RPM: 5947 / 6475; CPU ~86.5 °C, GPU ~71.8 °C.
- Each fan individually accepted exact target 2317 RPM, confirmed by SMC mode/target read-back. Sync 100% and 0% confirmed maximum/minimum targets for both. Exact maximum targets 7826 RPM confirmed.
- Automatic recovery confirmed; independent final diagnostic showed `Ftst=0`, `F0Md=0`, `F1Md=0`. Actual spin-down is gradual and need not immediately match the target.
- No artificial heating was performed. Threshold behavior was verified in controller tests, not by overheating the real Mac.
- SwiftPM prints its existing deprecation warning for `--build-system native`.
