# Firmware package architecture

This directory is the modular source of truth for development firmware **v4.1.2** on `v4-lvgl-menu`, assembled by `../r4875g1-3phase-charger.yaml`. Stable `main` remains at v4.1.0 until development changes are hardware-tested and promoted.

## Ownership rules

| File | Responsibility |
|---|---|
| `version.yaml` | single source of truth for firmware version; normal commits increment PATCH |
| `core.yaml` | ESP32 platform/framework, PSRAM, network, API, MQTT, web, OTA and time services |
| `hardware.yaml` | shared I²C and SPI buses |
| `display.yaml` | display package aggregator and rotation substitution |
| `display/hardware.yaml` | ILI9488 transport, panel transform and backlight |
| `display/theme.yaml` | LVGL, RGB565 framebuffer, fonts and reusable styles |
| `display/ui.yaml` | LVGL page aggregator and page wrapping |
| `display/pages/dashboard.yaml` | compact charger overview and local setpoints |
| `display/pages/rectifiers.yaml` | complete per-rectifier overview with state-aware status emphasis |
| `display/pages/cooling.yaml` | compartment/external-fan page |
| `display/pages/system.yaml` | controller/network/memory/CAN diagnostics |
| `cooling.yaml` | external chassis fan enable/PWM/tach |
| `controls.yaml` | charger-wide setpoints and shared/broadcast controls |
| `rectifier-unit.yaml` | parameterized R4875G1 instance, discovery helpers and per-unit entities |
| `rectifier-shared.yaml` | lifecycle/discovery orchestration, shared limits/scripts, schedulers and physical CAN component |
| `rectifier-can/*.yaml` | parameterized per-unit CAN receive handlers |

## v4 display architecture

The ILI9488 UI is layered into display hardware, theme, page aggregation and four page files. `display/ui.yaml` enables page wrapping.

Current pages:

- **Dashboard** — operating overview and local setpoints.
- **Rectifiers** — L1/L2/L3 cards with Power State, CAN state, lifecycle, DC V/A/W, input/output temperature, internal fan RPM and maximum-current capability. In v4.1.2 the operational status is a dedicated colored line: CAN fault red, discovery amber, online green and offline/neutral muted. Telemetry stays neutral and unreachable units use placeholders.
- **Cooling** — compartment temperature/humidity, external fan power/PWM and three tachometer speeds.
- **System** — firmware, IP, Wi-Fi RSSI, uptime, CPU temperature, free internal heap, free PSRAM and compact L1/L2/L3 CAN state.

Encoder gestures remain: short press selects Voltage/Power, double press advances the LVGL page, and ≥3 s performs START/STOP. Page wrapping returns from System to Dashboard.

The System page reads uptime from `millis()`, internal heap from `heap_caps_get_free_size(MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT)` and PSRAM from `heap_caps_get_free_size(MALLOC_CAP_SPIRAM)`, avoiding duplicate TFT-only entities.

The TFT and `esphome.project.version` both consume `${firmware_version}` from `version.yaml`.

## Rectifier unit template and CAN lifecycle

`rectifier-unit.yaml` is included three times with `ru_unit` set to `1`, `2` and `3`. Public IDs and entity names remain stable. The CAN connectivity watchdog uses 3 s normally and 7 s during `DISCOVERING`. Discovery waits for TWAI `RUNNING`; BUS_OFF/recovery wait time does not consume discovery retries.

The physical `esp32_can` component exists once in `rectifier-shared.yaml`; repeated RX handlers live under `rectifier-can/`. Unknown reachable capability forces the 50 A fail-safe ceiling; once all reachable capabilities are known, the effective ceiling uses the lowest reachable capability and command scaling the highest reachable capability.

## Deployment boundary

`scripts/deploy-ha.ps1` manages the root project YAML plus only `packages/**/*.yaml`. README and other non-YAML files are not deployed. The script reads the central version, stages files, verifies SHA-256 hashes, optionally backs up managed files, installs and verifies the YAML set, then removes staging.

## Change discipline

Preserve public ESPHome IDs/entity names, CAN identifiers/payloads, protocol scaling, timing/order, lifecycle transitions, requested/applied current semantics, thermal thresholds and blackstart safety unless a change explicitly targets them.

Every normal commit increments PATCH exactly once via `version.yaml`; release milestones may advance MAJOR/MINOR and reset PATCH. README documentation must stay synchronized with documented behavior, architecture and tooling. Commit messages use a concise subject plus explanatory bullet points.

Validate meaningful changes with:

```text
git diff --check
esphome config r4875g1-3phase-charger.yaml
esphome compile r4875g1-3phase-charger.yaml
```

Display changes also require physical ILI9488 verification because text density and RGB565 rendering are hardware-visible concerns.

## Fan terminology

External/chassis fans are GPIO-controlled through `cooling.yaml`; internal R4875G1 fans shown on Rectifiers are CAN-reported by each rectifier.

## Release / branch status

Firmware **4.1.0** remains stable on `main`. Firmware **4.1.2** on `v4-lvgl-menu` adds Rectifiers-page visual status emphasis only; charger-control, CAN-discovery, thermal and blackstart behavior are unchanged.
