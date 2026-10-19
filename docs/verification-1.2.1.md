# STIX System 1.2.1 (build 8) — 2026-10-19

## Reproduced causes

1. The initial installed panel reported CPU/GPU ~60–64 °C while ProcessInfo thermalState was serious (2). The application's existing safety policy rejected manual control before any SMC write. A separate thermal-pressure notification also reported elevated pressure. pmset and the available thermalmonitord log did not expose a specific cause; iCloud, indexing and Swift compilation load were observed, but causation was not established.
2. Later thermalState fell to fair (1), permitting manual requests, but SMC rejected F0Md writes (0xe00002bc). The firmware remained mode 3 with fans stopped, targets zero and Ftst=0 before the request.

## Changes

The panel now distinguishes system restrictions from measured CPU/GPU ≥95 °C, shows the exact serious/critical reason and disables only manual Apply while that reason is active. Auto remains available. This does not relax the thermal policy.

Fixed an independent retry bug: the former manual-transition loop exited when its first write threw. It now retries transient mode/target write failures at 100 ms intervals for up to 100 attempts, requiring successful write plus mode/target read-back. Persistent mode 3 is reported in plain language rather than only a hexadecimal code. Existing timeout, owner, journal, disconnect and thermal recovery remain.

## Verification

- 37 XCTest tests passed, zero failures. Added cases for a cool CPU/GPU with serious system state, restoration of availability when the state returns to nominal, transient SMC write rejection followed by acknowledgement, bounded permanent rejection and failed read-back despite successful writes.
- Signed release installed and service enabled; strict bundle signature verification passed.
- A real exact-RPM test from idle mode 3 did NOT succeed, even after the full retry window: F0Md=3, target=0, Ftst=1 at failure. Subsequent independent diagnostic confirmed safe cleanup to Ftst=0 with F0Md/F1Md=3 and targets zero. This is a remaining firmware handoff limitation, not a verified successful repair of manual control on the current idle state.
- Requested a lid close/open from the user for a wake/handoff retry. Result pending.
- One earlier signing attempt encountered an unavailable timestamp server; a later normal timestamped Developer ID build succeeded. Existing native SwiftPM deprecation warning remains.
