# 3-Phase Huawei R4875G1 Battery Charger Controller

ESPHome controller for **three Huawei R4875G1 rectifiers** operated as a coordinated three-phase battery charger with a common parallel DC output.

**Current stable firmware: 4.1.0** on `main`. **Current UI development firmware: 4.1.6** on `v4-lvgl-menu`.

Version 4.1 retains the validated charger, CAN-recovery, thermal-protection and local-blackstart model while adding the four-page LVGL interface. Development v4.1.6 adds automatic external compartment cooling without changing rectifier CAN control.

For detailed runtime behavior, see `R4875G1_CONTROL_FLOWS.md`. Package ownership and maintenance rules are documented in `packages/README.md`.

> [!WARNING]
> This project controls mains-powered equipment and a high-current DC battery bus. Firmware is not a substitute for correctly engineered fuses, breakers, disconnects, BMS protection, earthing, isolation and conductor sizing.

## Key features

- Three R4875G1 rectifiers controlled by one ESP32-S3 with common active DC voltage/current setpoints.
- CAN-aware lifecycle (`OFFLINE`, `DISCOVERING`, `ONLINE`), capability discovery, watchdog and TWAI recovery.
- Local encoder blackstart control with Voltage/Power selection, double-click page navigation and >=3 s START/STOP.
- Thermal current derating and per-unit overtemperature lockout.
- Four-page LVGL TFT interface: Dashboard, Rectifiers, Cooling and System.
- Automatic external compartment-fan curve with manual override and fail-safe full cooling on invalid temperature data.
- Home Assistant, MQTT and Wi-Fi remain optional for core charger operation.

## Versioning

The firmware version has one source of truth in `packages/version.yaml`. `esphome.project.version` and the TFT consume `${firmware_version}`. Every normal repository commit increments PATCH by one; intentional release milestones may advance MAJOR/MINOR and reset PATCH.

## Four-page UI

The installation has no touchscreen. Scrolling and `scrollbar_mode: OFF` are configured globally in the shared LVGL theme and explicitly once on every page/header/card container.

`Dashboard` provides the compact charger operating overview and local setpoints.

`Rectifiers` shows L1/L2/L3 with color-coded `PWR / CAN / lifecycle`, DC voltage/current/power, input/output temperature, internal fan RPM and maximum-current capability.

`Cooling` shows compartment temperature/humidity, automatic/manual mode, external fan power, commanded PWM, the active automatic stage and external fan 1/2/3 RPM.

`System` shows firmware, IP address, Wi-Fi RSSI, controller uptime, CPU temperature, free internal heap, free PSRAM and L1/L2/L3 CAN communication state.

## Automatic external cooling

`Cooling Fan Automatic` is enabled by default and uses the AHT10 compartment temperature. The upward curve is:

| Temperature | External fan command |
|---|---:|
| `< 30 °C` | Power OFF / 0 % PWM |
| `30–34.9 °C` | Power ON / 35 % PWM |
| `35–39.9 °C` | 45 % PWM |
| `40–44.9 °C` | 60 % PWM |
| `45–49.9 °C` | 80 % PWM |
| `>= 50 °C` | 100 % PWM |

Downward transitions use 2 °C hysteresis: 100→80 % below 48 °C, 80→60 % below 43 °C, 60→45 % below 38 °C, 45→35 % below 33 °C, and fan power switches off below 28 °C. Rising temperature always advances immediately to the required higher stage.

If the compartment temperature is unavailable or invalid while automatic mode is enabled, the controller fails safe to **fan power ON + 100 % PWM**. Disable `Cooling Fan Automatic` to use `Cooling Fan Power` and `Cooling Fan PWM` manually. Three-pin fans follow the common power switch only; four-pin fans additionally follow PWM.

## CAN and lifecycle

The normal per-unit CAN watchdog is 3 s and extends to 7 s while `DISCOVERING`. Discovery waits for TWAI `RUNNING`; BUS_OFF/recovery wait time does not consume discovery attempts. Before a rediscovered unit returns to `ONLINE`, active voltage/current setpoints are restored to that unit.

Capability handling is CAN-aware: unknown reachable capability forces the 50 A fail-safe ceiling; once all reachable capabilities are known, the effective ceiling uses the lowest reachable capability (max 75 A) while command scaling uses `1024 / highest reachable capability`.

## Deployment from Windows

`scripts/deploy-ha.ps1` derives the destination YAML filename from `esphome.name`, reads the firmware version from `packages/version.yaml`, deploys the root YAML plus only `packages/**/*.yaml`, excludes README/non-YAML files, stages and SHA-256-verifies uploads, optionally backs up managed target files, verifies installed hashes and cleans its staging directory. `-DryRun` is supported.

## Known limitations

- Optimized for three R4875G1 units.
- Nominal total-power calculation always divides by three.
- Capability mismatch is diagnostic and does not automatically disable charging.
- Blackstart still requires power for ESP32/CAN electronics.
- External fan RPM-failure alarms are not implemented yet.
- Software does not replace hardware protection.

## Credits and license

The repository is distributed under the MIT License and builds on the Huawei R48xx CAN research published by `mjpalmowski` in the `CAN-BUS-control-R4875G1-with-ESPHome-and-MQTT` project.

Copyright (c) 2024 mjpalmowski  
Additional project development: Copyright (c) 2026 Andreas Wansner

## Documentation status

Stable `main` remains at **v4.1.0**. This README documents development firmware **v4.1.6** on `v4-lvgl-menu`, including automatic external compartment cooling, manual override and temperature-sensor fail-safe behavior.
