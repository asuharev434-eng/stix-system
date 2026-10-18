# STIX System 1.1.2 (build 4) — 2026-10-18

## Requested behavior

Both unit modes allow arbitrary requested speeds from zero through the SMC maximum. No separate Stop button. On this Mac the selectable range is 0–7826 RPM. Percentages linearly map to zero–maximum, independently for each fan or with Sync. The reported SMC minimum remains telemetry, not a software floor. Targets below that value may differ from physically achievable speeds.

CPU/GPU ≥95 °C, OS serious/critical, connection loss, lease expiry and crash recovery still return control to macOS. Temperature limits were not relaxed for testing.

## Findings and recovery

The original screenshot's physical-stop report could not be independently reconstructed. The application reads actual values directly from F0Ac/F1Ac, separately from targets F0Tg/F1Tg, with no minimum clamp on displayed actual RPM.

Real zero-target testing on this Mac confirmed measured RPM declining through ~200 RPM to exactly zero on both fans. This exposed an important firmware transition issue: mode writes can fail when stopped, including redundant writes of manual=1. The initial restoration implementation failed; recovery intent remained journaled. An upgraded helper restarted the fans, restored both modes to automatic and released Ftst. A recorded intermediate sample reached CPU ~106.7 °C during this fault; after recovery the fans measured ~6333/6894 RPM and the temperature declined. This was an unintended fault, not an induced thermal stress test.

The final restoration sequence starts all stopped fans with a nonzero target before releasing any mode, avoids rewriting an already-manual mode, retries the asynchronous mode transition, and only releases Ftst after both modes acknowledge Auto. Failed restoration remains journaled and the watchdog retries it.

## Automated checks

32 XCTest tests cover zero targets, independent versus Sync operation, arbitrary RPM below the reported minimum, out-of-range/nonfinite rejection, nominal-state CPU/GPU thermal protection and owner/lease/crash recovery. Release app/helper signed with existing Developer ID; installed bundle strictly verified. SwiftPM's existing native-build-system deprecation warning remains.

## Final hardware validation

- A hot-state attempt was rejected at CPU/GPU approximately 100 °C and left both fans in Auto, Ftst=0.
- After the user paused the heavy workload, CPU/GPU were approximately 86/70 °C. The installed final binary `--fan-stop-test` passed: both measured RPM declined to exactly 0 with manual=true and target=0, then Automatic recovery was acknowledged without error.
- A separate read-only diagnostic after recovery confirmed F0Md=0, F1Md=0 and Ftst=0, measured RPM approximately 6231/6816 and CPU ~81 °C.
- Final source tests: 32 passed, zero failures. The final mode-release implementation was validated on hardware; it retries mode writes rather than assuming an arbitrary physical spin-up deadline.

- Installed final binary `--fan-individual-test` passed: fan 0 alone, distinct targets for both fans, partial Auto preserving fan 1 manual, 16 seconds of lease renewal, then full Auto.
