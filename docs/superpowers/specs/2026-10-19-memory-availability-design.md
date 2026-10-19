# Accurate memory availability and swap activity

The user requested more accurate available RAM, memory pressure and performance while preserving minimalism and updating the Mac and GitHub. The user selected swap activity in MB/s as the performance metric, rather than an inferred overall responsiveness label.

Keep the current memory usage heading/bar. Add a compact available/cache row, retain pressure with an explicit color indicator, retain the combined Swap/Compressed row, and add one swap read/write rate row. No new controls or synthetic benchmark.

Use resident anonymous pages minus purgeable pages, wired pages and actual compressor pages for used RAM. Available is total minus used; cached is file-backed plus reclaimable anonymous pages, bounded by available. Cached is a subset of available, compressed is a subset of used. Never add the compressor's uncompressed equivalent to physical memory. Describe available as an estimate.

Compute logical swap throughput from the differences in cumulative swapins/swapouts pages and monotonic sample time. Initial, reset and stale (>10 second) samples are unavailable. An idle interval produces zero. Label arrows and explain the physical-SSD-byte and responsiveness distinction in help text.

Verify accounting with deterministic counter fixtures, rate/reset/long-gap tests, live vm_stat comparison, signed build/install, native panel inspection, and GitHub remote commit verification. Keep existing fan protections and controls intact.
