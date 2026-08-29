# Firmware package architecture

This directory is the modular source of truth for firmware **v4.0.8** on development branch `v4-lvgl-menu`, assembled by `../r4875g1-3phase-charger.yaml`.

## Ownership rules

| File | Responsibility |
|---|---|
| `version.yaml` | single source of truth for firmware version; every repository commit increments PATCH |
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

Version 4 uses **ESPHome LVGL** on the ILI9488. The physical panel is 480×320 RGB565; LVGL rotation `90` produces the default **320×480 portrait UI**. The ESP32-S3 N16R8 has 8 MB PSRAM and LVGL uses a 100% 16-bit RGB565 framebuffer.

The display stack is deliberately layered:

```text
display.yaml
└── display/
    ├── hardware.yaml
    ├── theme.yaml
    └── ui.yaml
        └── pages/
            ├── dashboard.yaml
            ├── rectifiers.yaml
            ├── cooling.yaml
            └── system.yaml
```

`display/ui.yaml` enables `page_wrap` and includes all four page files. Each page owns its own widgets and periodic label updates.

### Current page content

**Dashboard** currently contains date/time, firmware, overall rectifier ON/OFF state, combined AC/DC summaries, available-unit count, highest output temperature, conversion efficiency and local Voltage/Power/Applied-current setpoints.

**Rectifiers** currently contains one card each for L1/L2/L3. Each card reports CAN fault state or power state plus DC voltage, DC current, DC power and output temperature. The planned input-temperature, internal-fan, capability and lifecycle fields are **not implemented on this page yet**.

**Cooling** currently contains compartment temperature/humidity, external fan power, external PWM command and fan 1/2/3 RPM.

**System** currently contains firmware in the header, IP address, Wi-Fi RSSI, CPU temperature and L1/L2/L3 CAN communication state. Planned Uptime/Heap/PSRAM fields are **not implemented on this page yet**.

The page definitions exist, but the physical encoder button still has its pre-menu behavior: short press selects Voltage/Power and ≥3 s performs START/STOP. **Double-click page navigation is the next implementation step.** Do not describe it as functional until the root button automation is changed and hardware-tested.

The TFT and `esphome.project.version` both consume `${firmware_version}` from `version.yaml`.

## Rectifier unit template

`rectifier-unit.yaml` is included three times with `ru_unit` set to `1`, `2` and `3`. Public IDs and entity names remain stable, for example `dc_voltage_1`, `output_temperature_1`, `can_com_ok_1` and `on_button_1`.

The per-unit CAN connectivity watchdog uses a **3 s normal timeout** and a **7 s timeout while lifecycle state is `DISCOVERING`**. The extended discovery timeout deliberately exceeds the 5 s stabilization delay so a newly detected rectifier does not falsely become unreachable before discovery starts.

Per-unit discovery also waits until the shared TWAI controller is `RUNNING`. Time spent in `BUS_OFF`, `RECOVERING` or `STOPPED` does not consume a property/capability discovery attempt. Actual transmitted requests still count toward the configured retry limits.

## CAN handler templates

The physical `esp32_can` component exists exactly once in `rectifier-shared.yaml`. Repeated RX handlers are included inside its `on_frame` list from `rectifier-can/`:

- `property-start.yaml` — property START/DATA (`0x108xD27F`)
- `property-end.yaml` — property END (`0x108xD27E`)
- `cyclic-telemetry.yaml` — telemetry/heartbeat (`0x108x407F`)
- `fan-telemetry.yaml` — internal fan telemetry (`0x108x827E`)
- `address-data.yaml` — shelf/slot addressing (`0x108x507E`)
- `power-state.yaml` — current + ON/OFF/ERROR (`0x100x117E`)

Maximum-current capability handlers remain explicit in `rectifier-shared.yaml`. Shared `effective_dc_current_limit` and `current_scaling_factor` are recomputed from currently CAN-reachable rectifiers. A reachable unit with unknown capability forces the 50 A fail-safe ceiling; once all reachable capabilities are known, the effective ceiling uses the lowest reachable capability and command scaling uses the highest reachable capability.

## Shared behavior that stays explicit

Cross-unit lifecycle coordination, serialized discovery, CAN-aware capability handling, staged thermal derating, blackstart safety, slow Single-Shot reconnect probing, TWAI BUS_OFF recovery, fixed fast-poll timing and aggregate charger telemetry intentionally remain shared rather than being hidden in the unit template.

## Deployment boundary

`scripts/deploy-ha.ps1` treats the root project YAML separately and recursively manages **only `packages/**/*.yaml`**. `packages/README.md` and any future non-YAML documentation/assets under `packages/` are not deployed to Home Assistant.

The deployment script reads the displayed firmware version from `version.yaml`, stages files remotely, verifies SHA-256 hashes, optionally backs up the currently managed files, installs the staged YAML files and verifies the installed hashes.

## Change discipline

Preserve public ESPHome IDs/entity names, CAN identifiers/payloads, protocol scaling, timing/order, lifecycle transitions, requested/applied current semantics, thermal thresholds and blackstart safety unless a change explicitly targets them.

Repository convention: **every commit increments PATCH exactly once**, with `version.yaml` as the single version source.

Validate meaningful changes with:

```text
git diff --check
esphome config r4875g1-3phase-charger.yaml
esphome compile r4875g1-3phase-charger.yaml
```

For display changes, also verify the physical ILI9488 because panel rotation, font rendering, page layout and RGB565 appearance are hardware-visible concerns.

## Fan terminology

Two independent fan domains exist: external/chassis fans are GPIO-controlled through `cooling.yaml`; internal R4875G1 fans are controlled and read through Huawei CAN commands. Documentation and comments must keep these domains distinct.

## Release / branch status

Firmware **4.0.8** is the current development baseline on `v4-lvgl-menu`. The stable `main` branch remains separate while the four-page UI is developed and hardware-tested. Charger control, CAN recovery and blackstart behavior continue from the validated v4 baseline unless a change explicitly targets them.
