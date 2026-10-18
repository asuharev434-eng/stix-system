# STIX System — approved design

Native macOS 14+ SwiftUI menu bar utility. One compact panel: CPU load with a short history, used RAM and memory pressure, disk free space and read/write throughput, top five processes sorted by resident RAM, thermal state, and fan RPM/control. Russian UI, system light/dark appearance, minimal controls; no accounts, network requests, analytics, or cloud storage.

Metrics come from Mach, libproc, statvfs and IOKit; unavailable measurements are explicitly unavailable, never fabricated. Slow collection runs outside the main actor. CPU and disk rates use monotonic deltas; first sample has no rate. Process rows show PID for disambiguation. RAM uses physical usage and pressure rather than claiming all cached pages are application memory.

AppleSMC is a private hardware interface, isolated behind a C bridge with validated types, sizes, fan counts and hardware-provided limits. Default is firmware automatic control. Privileged writes are limited to fan control through a local authenticated service; no arbitrary command execution. A short renewable lease restores automatic mode on client loss, timeout, sleep, termination, thermal emergency or failure. Updated user requirement (2026-10-18): allow any requested RPM from zero through the SMC maximum, including stop, with CPU/GPU ≥95 °C and OS serious/critical automatic recovery. Firmware may limit achievable speeds; report measured RPM separately from target. Unsupported hardware remains monitoring-only with an actionable message.

Build app and service locally with ad-hoc signing, install the app into ~/Applications, run real hardware diagnostics and UI smoke checks. Developer ID signing/notarization are outside local verification. Publish sources to a private GitHub repository because no public visibility was requested.

User approved this design and added top-five RAM processes on 2026-10-18, explicitly authorizing build, local testing and GitHub publication.

## Approved additions during implementation

- Independent controls and Auto for each fan; Sync switch for shared editing. A partial Auto operation must preserve the other fan's manual setting and lease.
- Separate component temperatures: CPU, GPU, memory proximity, NAND SSD, battery. Use model-specific sensor identities; aggregate component maxima; unavailable values are explicit.
- Notch-safe placement: use the screen visible frame and top safe area, clamp horizontal position, and scroll on short displays.
- Certificate issuance/import was explicitly approved. A Developer ID Application identity is installed in the local keychain; signing secrets remain outside the repository.

## Version 1.1 approved scope

Add login-at-startup, local sustained-health notifications with suppression, per-process CPU and CPU/RAM ranking. Retain both percent and absolute RPM fan settings and display actual/target RPM. Keep the dashboard minimal with settings behind a gear menu. Remove the lower material seam and unused fixed-height space. User explicitly requested local update and GitHub delivery; existing fan safety limits remain in force.
