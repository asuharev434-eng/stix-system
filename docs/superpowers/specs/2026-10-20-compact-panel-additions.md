# Compact panel additions

The user approved all four proposed additions: network throughput and battery as persistent compact rows, RAM/temperature history on demand, and a choice of CPU/GPU/CPU temperature in the menu bar instead of the icon.

Read active Wi-Fi/Ethernet carrier interfaces using 64-bit route counters. Track per-interface baselines so new, removed or reset interfaces cannot cause spikes; do not sum VPN/tunnel/bridge traffic twice. Battery uses public IOPowerSources data, validates capacity and distinguishes charging, external power and battery power. Missing data remains unavailable.

Keep at most 451 points per metric and 15 minutes, in memory only. Record gaps and invalidate history on backward clock movement. RAM stores actual usage fraction, temperatures their Celsius values. One selection controls the expanded chart, which is collapsed when the panel is reopened. During warm-up chart axes show only elapsed history, never fabricated earlier readings.

A persisted menu-metric preference defaults to the existing icon. Text modes show one metric with monospaced digits and compact variable width. The existing placement rules still constrain the panel beneath the notch.

Implementation files: SystemCore PanelSignals/SystemSignalsReader/Models/MetricsSampler, STIXSystem MonitorModel/AppPreferences/App/DashboardView/DiagnosticCommands. No new privileges or packages. Verify fixtures, live telemetry, signed install, expanded chart controls, metric selection and persistence, then push source to GitHub.
