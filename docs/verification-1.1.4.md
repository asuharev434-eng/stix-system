# STIX System 1.1.4 (build 6) — 2026-10-19

The existing Swap row now also shows «Сжато», with two compact groups on one line. Both values use the same two-decimal GB formatter (1024³ bytes). Compressed memory is the physical RAM occupied by the compressor: `vm_statistics64.compressor_page_count × host_page_size`, rather than the uncompressed equivalent.

Verification:
- 32 XCTest tests passed with zero failures; release build and strict signature verification passed.
- Sampled compressed memory: 7927054336 bytes = 7.38 GB. Adjacent `vm_stat`: 483828 pages × 16384 bytes = 7927037952 bytes = 7.38 GB. The one-page change is expected between successive live samples.
- Signed version 1.1.4 installed in ~/Applications; daemon registration enabled (status 1).
- Installed app accessibility inspection confirmed `Swap 4.90 ГБ Сжато 7.33 ГБ`; subsequent screenshot confirmed both groups occupy the same row without wrapping or clipping. Values continue updating with system activity.
- Existing native SwiftPM build-system deprecation warning remains.
