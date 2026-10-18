# STIX System 1.1.0 — 2026-10-18

Verified on the same MacBook Pro M4 Pro (Mac16,8), macOS 27.0.1, 24 GB RAM. Existing 1.0 application was backed up by the installer before replacement.

- Final `swift test --build-system native`: **27 tests, 0 failures**. New tests cover per-process CPU deltas, PID reuse, Apple Silicon timebase conversion, both rankings, sustained alert delays, no duplicate alerts, cooldown, sleep gaps, explicit RPM boundaries, and exact RPM forwarding/recovery through the fan controller.
- Release compiled and the application/helper were signed with Developer ID Application, team 9TB7MZWNXU. Installed application version 1.1.0, build 2.
- Native screenshot: the lower strip is gone. Dashboard has no separate material layer, the viewport owns one background, and the window height follows measured content. The notch-safe outer bounds and short-display scrolling remain intact.
- UI inspected with CPU and RAM columns, clickable sort headers, separate fans, Sync, percent/RPM selector, and actual → target RPM. Clicking CPU changed the five visible processes to CPU ranking immediately.
- Live CPU comparison after Mach timebase conversion: sampled Yandex Helper **25.5%**, `ps` **25.5%**; sampled renderer **22.1%**, `ps` **22.6%**. Values are sampled over different windows; no claim of exact agreement for transient workloads. Some protected system processes are unavailable to the unprivileged sampler.
- Exact-RPM hardware test: both targets read back **7826 RPM**, then automatic mode and Ftst=0 confirmed; PASS.
- Percentage hardware test: targets **7769 / 7799 RPM**, physical RPM **7785 / 7791**, followed by both fan flags automatic and Ftst=0; PASS.
- Main-app login item status **1 (enabled)**; verified in System Settings login-items list.
- Notification authorization **2 (authorized)**; STIX System notification switch enabled in System Settings. Diagnostic notification test returned successfully only after a fresh UUID identifier appeared in `deliveredNotifications()` (not a previously delivered test message).
- Alert-duration and anti-spam policies are unit-tested. Actual low-disk/critical-memory conditions were not induced on the user's Mac. No forced heating, logout/login or reboot was performed.
- Both fans were left under macOS automatic control after hardware tests. Normal application reopened with the user's saved display preferences.

SMC remains a private hardware interface. Other hardware models, physical sleep/crash recovery and notarization are outside this update's live verification. The explicit RPM endpoint uses the same ownership, validation, lease, recovery journal and thermal safety policy as percentage mode.
