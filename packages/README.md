# Firmware package architecture

This directory is the modular source of truth for stable firmware **v4.1.0**, assembled by `../r4875g1-3phase-charger.yaml`. The `v4-lvgl-menu` branch continues from the same release baseline for further UI development.

## Ownership rules

| File | Responsibility |
|---|---|
| `version.yaml` | single source of truth for firmware version; every repository commit increments PATCH unless an intentional release milestone advances MAJOR/MINOR |
| `core.yaml` | ESP32 platform/framework, PSRAM, network, API, MQTT, web, OTA and time services |
| `hardware.yaml` | shared I²C and SPI buses |
| `display.yaml` | display package aggregator and rotation substitution |
| `display/hardware.yaml` | ILI9488 transport, panel transform and backlight |
| `display/theme.yaml` | LVGL, RGB565 framebuffer, fonts and reusable styles |
| `display/ui.yaml` | LVGL page aggregator and page wrapping |
| `display/pages/dashboard.yaml` | compact charger overview and local setpoints |
| `display/pages/rectifiers.yaml` | per-rectifier diagnostic page |
| `display/pages/cooling.yaml` | compartment/external-fan page |
| `display/pages/system.yaml` | controller/network/CAN page |
| `cooling.yaml` | external chassis fan enable/PWM/tach |
| `controls.yaml` | charger-wide setpoints and shared/broadcast controls |
| `rectifier-unit.yaml` | one parameterized R4875G1 instance, discovery helpers and per-unit entities |
| `rectifier-shared.yaml` | lifecycle/discovery orchestration, shared limits/scripts, schedulers and physical CAN component |
| `rectifier-can/*.yaml` | parameterized per-unit CAN receive handlers |

## v4 display architecture

Version 4 uses ESPHome LVGL on the ILI9488. The display stack is deliberately layered into hardware, theme, page aggregation and four page files. `display/ui.yaml` enables page wrapping.

Current pages:

- **Dashboard** — operating overview and local setpoints.
- **Rectifiers** — L1/L2/L3 power state, DC V/A/W, output temperature and CAN fault presentation; further per-unit diagnostics remain planned.
- **Cooling** — compartment temperature/humidity, external fan power/PWM and three tachometer speeds.
- **System** — firmware, IP, Wi-Fi RSSI, CPU temperature and per-unit CAN state; uptime/heap/PSRAM remain planned.

The physical encoder button distinguishes three gestures: short press selects Voltage/Power, double press advances to the next LVGL page, and ≥3 s performs START/STOP. The double-click pattern requires the second press within 350 ms; the single-click pattern waits at least 350 ms after release so both actions cannot fire for the same gesture. Page wrapping returns from System to Dashboard.

The TFT and `esphome.project.version` both consume `${firmware_version}` from `version.yaml`.

## Rectifier unit template and CAN lifecycle

`rectifier-unit.yaml` is included three times with `ru_unit` set to `1`, `2` and `3`. Public IDs and entity names remain stable.

The per-unit CAN connectivity watchdog uses a 3 s normal timeout and a 7 s timeout while lifecycle state is `DISCOVERING`. Per-unit discovery waits until the shared TWAI controller is `RUNNING`; time spent in `BUS_OFF`, `RECOVERING` or `STOPPED` does not consume a property/capability discovery attempt.

The physical `esp32_can` component exists exactly once in `rectifier-shared.yaml`. Repeated RX handlers live under `rectifier-can/` for property, cyclic telemetry, fan telemetry, address and power-state frames.

Maximum-current capability handlers remain explicit in `rectifier-shared.yaml`. A reachable unit with unknown capability forces the 50 A fail-safe ceiling; once all reachable capabilities are known, the effective ceiling uses the lowest reachable capability and command scaling uses the highest reachable capability.

## Deployment boundary

`scripts/deploy-ha.ps1` treats the root project YAML separately and recursively manages **only `packages/**/*.yaml`**. `packages/README.md` and future non-YAML documentation/assets are not deployed to Home Assistant.

The deployment script reads the firmware version from `version.yaml`, stages files remotely, verifies SHA-256 hashes, optionally backs up currently managed files, installs the staged YAML files, verifies installed hashes and removes the staging directory.

## Change discipline

Preserve public ESPHome IDs/entity names, CAN identifiers/payloads, protocol scaling, timing/order, lifecycle transitions, requested/applied current semantics, thermal thresholds and blackstart safety unless a change explicitly targets them.

Repository convention: every normal commit increments PATCH exactly once, with `version.yaml` as the single version source. Intentional release milestones may advance MAJOR/MINOR and reset PATCH. README documentation must be synchronized whenever a change affects documented behavior, architecture or tooling.

Commit messages use a concise subject followed by bullet points explaining the relevant changes and effects.

Validate meaningful changes with:

```text
git diff --check
esphome config r4875g1-3phase-charger.yaml
esphome compile r4875g1-3phase-charger.yaml
```

For PowerShell tooling changes, also run a parser check or execute the script with `-DryRun` before relying on it for deployment.

## Fan terminology

Two independent fan domains exist: external/chassis fans are GPIO-controlled through `cooling.yaml`; internal R4875G1 fans are controlled and read through Huawei CAN commands.

## Release / branch status

Firmware **4.1.0** is the stable baseline promoted to `main` after physical verification of the four-page TFT navigation and deployment workflow. `v4-lvgl-menu` remains available and starts its next development work from this exact release commit; the next normal development commit will therefore be v4.1.1.
