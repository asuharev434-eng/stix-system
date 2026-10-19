# STIX System 1.4.0 (build 10) — 2026-10-20

## Delivered behavior

- Compact network row with download/upload from active Wi-Fi/Ethernet carrier interfaces. Uses 64-bit NET_RT_IFLIST2 counters, tracks each interface separately, excludes virtual/tunnel/bridge names to avoid double counting, handles resets/appearance/removal and stale intervals. No privileged network access or destination collection.
- Battery percentage and charging/external/battery state from public IOPowerSources. Validates presence, capacity and source type; the row is omitted without available internal battery data.
- RAM and each component temperature open a single history graph on click, retaining at most 451 samples and 15 minutes in memory. Gaps remain gaps; the displayed axis grows from the actual available history up to 15 minutes. Closing/reopening the panel collapses charts while the model keeps recording.
- Gear menu selects icon, CPU, GPU or CPU temperature for the menu bar. Selection persists via UserDefaults, updates through Combine, and uses compact monospaced text. The default for a fresh preference is the icon; CPU was selected during native UI verification and remains selected on this Mac.
- Slightly reduced card spacing and allowed panel expansion to the screen's safe available height instead of the former artificial 740-point maximum. Existing notch/margin bounds and scrolling on small screens remain.

## Validation

44 XCTest tests passed, zero failures. New tests cover network counter resets and new/removed interfaces, bounded history/gaps/backward clock, battery states and invalid capacity, all menu-metric formatting cases, and a regression for missing RAM temperature not overwriting RAM usage history.

Live diagnostic read download ~279034 bytes/s and upload ~17002 bytes/s; battery 99%, charging. Adjacent pmset reported 99%, finishing charge, on AC power. Native installed-panel inspection later showed nonzero network traffic in both directions and the battery row.

Native interaction verified that clicking memory reveals a real RAM history element, and clicking CPU temperature reveals the distinct CPU history element. An early implementation reused the identifier `memory` for usage and the RAM temperature sensor, resulting in unavailable charts; this was reproduced, replaced with separately typed histories/selections, and covered by regression test.

The gear menu exposed all four metric choices. CPU was selected through native UI; the app's preferences-status command reported `Menu metric: cpu`, and the value remained cpu across subsequent app restarts. Tests validate CPU/GPU/temperature/missing-value presentation. Some native observations were interrupted when the floating panel/menu lost focus; completed checks were retried from a fresh app launch.

Release app/helper use the existing timestamped Developer ID signature. Installed at ~/Applications/STIX System.app with the previous bundle backed up. Service registration required the known post-unregister retry, then returned enabled status 1. Strict signature verification passed. Fan controls and safety policy were not changed; no manual fan hardware tests were performed for these additions.

Existing SwiftPM native-build-system deprecation warning remains. Graph retention over a full 15 minutes was verified with synthetic timestamps in unit tests; live charts were validated with data accumulated since app launch.

Final signed installation and fresh-launch screenshot confirmed the collapsed panel fits both fan rows and Quit button without scrolling on this Mac, with no empty bottom material strip. Expanded graphs remain bounded by the screen's safe viewport. The persisted menu metric remained CPU across final installation and fresh launches.
