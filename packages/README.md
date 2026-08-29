# Firmware package architecture

This directory documents development firmware **v4.1.6** on `v4-lvgl-menu`. Stable `main` remains at v4.1.0 until development changes are hardware-tested and promoted.

## Display architecture

The ILI9488 uses ESPHome LVGL with separate hardware, theme, page aggregation and page files. The controller has no touchscreen, so scrolling and scrollbar rendering are disabled globally and explicitly on page/header/card containers.

Current pages are Dashboard, Rectifiers, Cooling and System. The Cooling page now reports automatic/manual state, fan power, commanded PWM, current automatic stage and all three external tachometer speeds.

Encoder behavior remains: rotate edits the selected charger setpoint, short press selects Voltage/Power, double press advances the page, and >=3 s performs START/STOP.

## External cooling package

`cooling.yaml` owns external/chassis fans only; internal R4875G1 fans remain CAN-controlled/reported separately.

`Cooling Fan Automatic` defaults ON. It evaluates the AHT10 compartment temperature every 5 seconds and applies six stages: OFF below 30 °C, then 35/45/60/80/100 % PWM at 30/35/40/45/50 °C. Downward transitions use 2 °C hysteresis (28/33/38/43/48 °C) to avoid rapid stage oscillation.

If compartment temperature is invalid, automatic mode fails safe to fan power ON and 100 % PWM. Disabling automatic mode stops the controller from changing fan power/PWM and leaves `Cooling Fan Power` plus `Cooling Fan PWM` available for manual override. Three-pin fans use only common power; four-pin fans use common power plus the shared 25 kHz PWM signal.

The current automatic stage is held in a non-persistent runtime global; the visible `Cooling Fan PWM` value is updated to the automatic command so Home Assistant and the TFT show the actual requested PWM.

## Package ownership

`version.yaml` is the single firmware-version source. `display/theme.yaml` owns shared LVGL behavior/styles. `display/ui.yaml` aggregates the four page files. `rectifier-unit.yaml` is instantiated for each rectifier; `rectifier-shared.yaml` owns shared CAN/lifecycle/discovery behavior. `cooling.yaml` owns external fan hardware and automatic cooling logic.

The normal CAN watchdog is 3 s and extends to 7 s while `DISCOVERING`. Discovery waits for TWAI `RUNNING`; recovery wait time does not consume discovery attempts.

## Deployment

`scripts/deploy-ha.ps1` deploys the root project YAML plus only `packages/**/*.yaml`. Non-YAML documentation is not copied to Home Assistant. The script uses staging, SHA-256 verification and optional backups.

## Change discipline

Every normal commit increments PATCH exactly once; intentional release milestones may advance MAJOR/MINOR. README documentation is synchronized whenever documented behavior, architecture or tooling changes. Commit messages use a concise subject followed by explanatory bullet points.

Validate meaningful changes with `git diff --check`, `esphome config r4875g1-3phase-charger.yaml` and `esphome compile r4875g1-3phase-charger.yaml`. Display and cooling-control changes must also be checked on the physical hardware.

## Release status

Firmware **4.1.0** remains stable on `main`. Firmware **4.1.6** on `v4-lvgl-menu` adds automatic external compartment cooling with hysteresis, manual override and sensor-failure full-speed fallback without changing rectifier CAN/discovery/blackstart behavior.
