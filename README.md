# 3-Phase Huawei R4875G1 Battery Charger Controller

ESPHome controller for **three Huawei R4875G1 rectifiers** operated as a coordinated three-phase battery charger with a common parallel DC output.

**Current stable firmware: 4.1.0** on `main`. **Current UI development firmware: 4.1.5** on `v4-lvgl-menu`.

Version 4.1 promotes the hardware-tested four-page LVGL interface and encoder page navigation to the stable baseline while retaining the validated charger, CAN-recovery, thermal-protection and local-blackstart model. Development v4.1.5 fixes the explicit non-touch scrollbar configuration after v4.1.4 introduced duplicate YAML keys in Dashboard cards.

For detailed runtime behavior, see `R4875G1_CONTROL_FLOWS.md`. Package ownership and maintenance rules are documented in `packages/README.md`.

> [!WARNING]
> This project controls mains-powered equipment and a high-current DC battery bus. Firmware is not a substitute for correctly engineered fuses, breakers, disconnects, BMS protection, earthing, isolation and conductor sizing.

## Project purpose

The intended installation uses one R4875G1 on each AC phase, all three DC outputs on one common battery/DC bus, identical DC voltage, a common per-unit current command and a nominal three-unit charging-power target. Core charger operation is local: Home Assistant, MQTT and Wi-Fi are useful interfaces but are not required for CAN control, the TFT/encoder or blackstart.

# Key features

- Three R4875G1 rectifiers controlled by one ESP32-S3 with common active DC voltage/current setpoints.
- CAN-aware lifecycle (`OFFLINE`, `DISCOVERING`, `ONLINE`), capability discovery, watchdog and TWAI recovery.
- Local encoder blackstart control with Voltage/Power selection, double-click page navigation and >=3 s START/STOP.
- Thermal current derating and per-unit overtemperature lockout.
- Four-page LVGL TFT interface: Dashboard, Rectifiers, Cooling and System.
- Home Assistant, MQTT and Wi-Fi remain optional for core charger operation.

# Firmware architecture

```text
r4875g1-3phase-charger.yaml
packages/
├── version.yaml
├── core.yaml
├── hardware.yaml
├── display.yaml
├── display/
│   ├── hardware.yaml
│   ├── theme.yaml
│   ├── ui.yaml
│   └── pages/
│       ├── dashboard.yaml
│       ├── rectifiers.yaml
│       ├── cooling.yaml
│       └── system.yaml
├── cooling.yaml
├── controls.yaml
├── rectifier-shared.yaml
├── rectifier-unit.yaml
└── rectifier-can/
```

# Versioning

The firmware version has one source of truth in `packages/version.yaml`. `esphome.project.version` and the TFT consume `${firmware_version}`. Every normal repository commit increments PATCH by one; intentional release milestones may advance MAJOR/MINOR and reset PATCH.

# Hardware

- Espressif ESP32-S3-DevKitC-1 / ESP32-S3-WROOM-1-N16R8
- 16 MB flash / 8 MB PSRAM
- SN65HVD230 CAN transceiver, 125 kbit/s, 29-bit extended identifiers
- ILI9488 TFT, 16-bit RGB565, 40 MHz SPI, full LVGL framebuffer in PSRAM
- AHT10 compartment temperature/humidity sensor
- external fan enable/PWM plus three tachometer inputs

## GPIO map

| Function | GPIO |
|---|---:|
| Encoder button | 2 |
| TFT backlight | 4 |
| TFT CS / RESET / DC | 5 / 6 / 7 |
| I²C SDA / SCL | 8 / 9 |
| SPI MOSI / MISO / CLK | 11 / 12 / 13 |
| CAN TX / RX | 15 / 16 |
| Encoder A / B | 17 / 18 |
| External fan enable | 21 |
| Fan tach 3 / 2 / 1 | 39 / 40 / 41 |
| Fan PWM | 42 |

# Four-page UI

The installation has no touchscreen. Scrolling and `scrollbar_mode: OFF` are configured globally in the shared LVGL theme and explicitly once on every page/header/card container. v4.1.5 corrects the v4.1.4 Dashboard generation bug that inserted duplicate `scrollbar_mode` keys into some cards.

`Dashboard` provides date/time and firmware, overall ON/OFF state, combined AC/DC summaries, available-unit count, highest output temperature, conversion efficiency and local Voltage/Power/Applied-current setpoints.

`Rectifiers` shows one card each for L1/L2/L3 with compact color-coded `PWR / CAN / lifecycle`, DC voltage/current/power, input/output temperature, internal fan RPM and discovered maximum-current capability. CAN-unreachable units use placeholders instead of stale live telemetry.

`Cooling` shows compartment temperature/humidity, external fan power, PWM command and external fan 1/2/3 RPM.

`System` shows firmware, IP address, Wi-Fi RSSI, controller uptime, CPU temperature, free internal heap, free PSRAM and L1/L2/L3 CAN communication state.

# CAN and lifecycle

The normal per-unit CAN watchdog is 3 s and extends to 7 s while `DISCOVERING` so the intentional 5 s stabilization delay does not falsely mark a new unit unreachable. Discovery waits for TWAI `RUNNING`; BUS_OFF/recovery wait time does not consume discovery attempts. Before a rediscovered unit returns to `ONLINE`, active voltage/current setpoints are restored to that unit.

Capability handling is CAN-aware: unknown reachable capability forces the 50 A fail-safe ceiling; once all reachable capabilities are known, the effective ceiling uses the lowest reachable capability (max 75 A) while command scaling uses `1024 / highest reachable capability`.

# Deployment from Windows

`scripts/deploy-ha.ps1` derives the destination YAML filename from `esphome.name`, reads the firmware version from `packages/version.yaml`, deploys the root YAML plus only `packages/**/*.yaml`, excludes README/non-YAML files, stages and SHA-256-verifies uploads, optionally backs up managed target files, verifies installed hashes and cleans its staging directory. `-DryRun` is supported.

# Known limitations

- Optimized for three R4875G1 units.
- Nominal total-power calculation always divides by three.
- Capability mismatch is diagnostic and does not automatically disable charging.
- Blackstart still requires power for ESP32/CAN electronics.
- External fan control has no automatic thermal curve or RPM-failure alarm yet.
- Software does not replace hardware protection.

# Credits and license

The repository is distributed under the MIT License and builds on the Huawei R48xx CAN research published by `mjpalmowski` in the `CAN-BUS-control-R4875G1-with-ESPHome-and-MQTT` project.

Copyright (c) 2024 mjpalmowski  
Additional project development: Copyright (c) 2026 Andreas Wansner

# Documentation status

Stable `main` remains at **v4.1.0**. This README documents development firmware **v4.1.5** on `v4-lvgl-menu`. v4.1.5 repairs the duplicate Dashboard YAML keys introduced during the explicit scrollbar cleanup while preserving the intended no-scrollbar policy and all charger-control behavior.
