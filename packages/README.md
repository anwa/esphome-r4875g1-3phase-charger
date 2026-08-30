# Firmware package architecture

This directory documents stable firmware **v4.2.0**, assembled by `../r4875g1-3phase-charger.yaml`.

## Display architecture

The ILI9488 uses ESPHome LVGL with separate hardware, theme, page aggregation and page files. The controller has no touchscreen, so scrolling and scrollbar rendering are disabled globally and explicitly on page/header/card containers.

All four pages share the same 64 px header geometry. Dashboard content starts at `y: 72`, matching Rectifiers, Cooling and System. The Dashboard second header line contains date/time, firmware and aggregate charger run state. `OFF`, `1/3 ON` and `2/3 ON` use bold bright red; only `3/3 ON` uses bright green.

Current pages are Dashboard, Rectifiers, Cooling and System. Rectifiers provides complete per-unit operating diagnostics; System provides network/runtime/memory/CAN diagnostics; Cooling reports automatic/manual state, fan power, commanded PWM, current automatic stage and all three external tachometer speeds.

Encoder behavior: rotate edits the selected charger setpoint, short press selects Voltage/Power, double press advances the page, and >=3 s performs START/STOP.

## External cooling package

`cooling.yaml` owns external/chassis fans only; internal R4875G1 fans remain CAN-controlled/reported separately.

`Cooling Fan Automatic` defaults ON. It evaluates the AHT10 compartment temperature every 5 seconds and applies six stages: OFF below 30 °C, then 35/45/60/80/100 % PWM at 30/35/40/45/50 °C. Downward transitions use 2 °C hysteresis at 28/33/38/43/48 °C.

Invalid compartment temperature fails safe to fan power ON and 100 % PWM. Disabling automatic mode leaves `Cooling Fan Power` and `Cooling Fan PWM` available for manual override. Three-pin fans use common power only; four-pin fans use common power plus shared 25 kHz PWM.

The AHT10/off-below-30 °C path has been observed on hardware. Full PWM/RPM behavior remains pending installation of the external fans.

## Package ownership

`version.yaml` is the single firmware-version source. `display/theme.yaml` owns shared LVGL behavior/styles. `display/ui.yaml` aggregates the four page files. `rectifier-unit.yaml` is instantiated for each rectifier; `rectifier-shared.yaml` owns shared CAN/lifecycle/discovery behavior. `cooling.yaml` owns external fan hardware and automatic cooling logic.

The normal CAN watchdog is 3 s and extends to 7 s while `DISCOVERING`. Discovery waits for TWAI `RUNNING`; recovery wait time does not consume discovery attempts.

## Deployment

`scripts/deploy-ha.ps1` deploys the root project YAML plus only `packages/**/*.yaml`. Non-YAML documentation is not copied to Home Assistant. The script uses staging, SHA-256 verification and optional backups.

## Change discipline

Every normal commit increments PATCH exactly once; intentional release milestones may advance MAJOR/MINOR. README documentation is synchronized whenever documented behavior, architecture or tooling changes. Commit messages use a concise subject followed by explanatory bullet points.

Validate meaningful changes with `git diff --check`, `esphome config r4875g1-3phase-charger.yaml` and `esphome compile r4875g1-3phase-charger.yaml`. Display and cooling-control changes must also be checked on physical hardware.

## Release status

Firmware **4.2.0** is the stable baseline on `main`. The four-page menu and AHT10 automatic cooling behavior tested so far are promoted from `v4-lvgl-menu`; full external fan PWM/RPM testing remains intentionally deferred until the fan hardware is installed.
