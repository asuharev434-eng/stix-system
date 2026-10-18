# STIX System — approved design

Native macOS 14+ SwiftUI menu bar utility. One compact panel: CPU load with a short history, used RAM and memory pressure, disk free space and read/write throughput, top five processes sorted by resident RAM, thermal state, and fan RPM/control. Russian UI, system light/dark appearance, minimal controls; no accounts, network requests, analytics, or cloud storage.

Metrics come from Mach, libproc, statvfs and IOKit; unavailable measurements are explicitly unavailable, never fabricated. Slow collection runs outside the main actor. CPU and disk rates use monotonic deltas; first sample has no rate. Process rows show PID for disambiguation. RAM uses physical usage and pressure rather than claiming all cached pages are application memory.

AppleSMC is a private hardware interface, isolated behind a C bridge with validated types, sizes, fan counts and hardware-provided limits. Default is firmware automatic control. Privileged writes are limited to fan control through a local authenticated service; no arbitrary command execution. A short renewable lease restores automatic mode on client loss, timeout, sleep, termination, thermal emergency or failure. Increasing cooling is preferred; no fan-stop feature. Unsupported hardware remains monitoring-only with an actionable message.

Build app and service locally with ad-hoc signing, install the app into ~/Applications, run real hardware diagnostics and UI smoke checks. Developer ID signing/notarization are outside local verification. Publish sources to a private GitHub repository because no public visibility was requested.

User approved this design and added top-five RAM processes on 2026-10-18, explicitly authorizing build, local testing and GitHub publication.
