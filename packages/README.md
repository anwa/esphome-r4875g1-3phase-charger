# Firmware package architecture

This directory documents development firmware **v4.1.4** on `v4-lvgl-menu`. Stable `main` remains at v4.1.0 until the display changes are hardware-tested and promoted.

## Display architecture

The ILI9488 uses ESPHome LVGL with separate hardware, theme, page aggregation and page files. The controller has no touchscreen, so scrolling and scrollbar rendering are disabled twice: globally in `display/theme.yaml` and explicitly on every page/header/card `obj` container. The explicit local settings avoid scrollbar-part inheritance differences in LVGL. New cards must fit their content rather than depend on touch scrolling.

Current pages:

- **Dashboard** — operating overview and local setpoints.
- **Rectifiers** — L1/L2/L3 cards with a compact color-coded `PWR / CAN / lifecycle` line, DC V/A/W, input/output temperature, internal fan RPM and discovered maximum-current capability. `UNKNOWN` power state is abbreviated to `?`; unreachable units use placeholders for live telemetry.
- **Cooling** — compartment temperature/humidity, external fan power/PWM and three external tachometer speeds.
- **System** — firmware, IP, Wi-Fi RSSI, uptime, CPU temperature, free internal heap, free PSRAM and L1/L2/L3 CAN state.

Rectifier status is red for CAN fault, amber while `DISCOVERING`, green while `ONLINE`, and muted while `OFFLINE`. Telemetry stays neutral.

Encoder behavior remains: rotate edits the selected setpoint, short press selects Voltage/Power, double press advances the LVGL page, and >=3 s performs START/STOP.

## Package ownership

`version.yaml` is the single firmware-version source. `display/theme.yaml` owns shared LVGL behavior/styles. `display/ui.yaml` aggregates the four page files. `rectifier-unit.yaml` is instantiated for each rectifier, while `rectifier-shared.yaml` owns shared CAN/lifecycle/discovery behavior.

The normal CAN watchdog is 3 s and extends to 7 s while `DISCOVERING`. Discovery waits for TWAI `RUNNING`; recovery wait time does not consume discovery attempts.

## Deployment

`scripts/deploy-ha.ps1` deploys the root project YAML plus only `packages/**/*.yaml`. Non-YAML documentation is not copied to Home Assistant. The script uses staging, SHA-256 verification and optional backups.

## Change discipline

Every normal commit increments PATCH exactly once; intentional release milestones may advance MAJOR/MINOR. README documentation is synchronized whenever documented behavior, architecture or tooling changes. Commit messages use a concise subject followed by explanatory bullet points.

Validate meaningful changes with `git diff --check`, `esphome config r4875g1-3phase-charger.yaml` and `esphome compile r4875g1-3phase-charger.yaml`. Display changes must also be checked on the physical TFT.

## Fan terminology

External/chassis fans are GPIO-controlled through `cooling.yaml`. Internal R4875G1 fans shown on the Rectifiers page are CAN-reported by each rectifier.

## Release status

Firmware **4.1.0** remains stable on `main`. Firmware **4.1.4** on `v4-lvgl-menu` adds the Rectifiers layout cleanup and the global non-touch no-scrollbar policy without changing charger-control, CAN-discovery or blackstart behavior.
