# STIX System 1.1.3 (build 5) — 2026-10-19

Added one Swap row below memory pressure. It reports used swap from Darwin `vm.swapusage` (`xsw_usage.xsu_used`), formatted with two decimals in GB using 1024³ bytes, consistently with the panel's memory units. Read failures show an em dash; zero remains zero.

Verification:
- 32 XCTest tests passed, zero failures; release build passed.
- Diagnostic sampled 5292490752 bytes = 4.93 GB. The adjacent `sysctl vm.swapusage` read reported 5047.31M used, matching after unit conversion.
- Installed signed 1.1.3 in ~/Applications; strict signature verification passed; daemon registration status 1.
- Native accessibility inspection of installed panel confirmed: `Давление памяти Нормальное Swap 4.93 ГБ Диск`.
- Existing native SwiftPM build-system deprecation warning remains.
