# Firmware package architecture

This directory is the modular source of truth for firmware **v4.0.4**, assembled by `../r4875g1-3phase-charger.yaml`.

## Ownership rules

| File | Responsibility |
|---|---|
| `version.yaml` | single source of truth for firmware version; every commit increments PATCH |
| `core.yaml` | ESP32 platform/framework, PSRAM, network, API, MQTT, web, OTA and time services |
| `hardware.yaml` | shared I²C and SPI buses |
| `display.yaml` | v4 display package aggregator and display substitutions |
| `display/hardware.yaml` | ILI9488 transport, panel transform and backlight |
| `display/theme.yaml` | LVGL, RGB565 framebuffer, fonts and reusable styles |
| `display/ui.yaml` | portrait dashboard widgets and dynamic display updates |
| `cooling.yaml` | external chassis fan enable/PWM/tach |
| `controls.yaml` | charger-wide setpoints and shared/broadcast controls |
| `rectifier-unit.yaml` | one parameterized R4875G1 instance |
| `rectifier-shared.yaml` | lifecycle/discovery orchestration, shared limits/scripts, schedulers and the physical CAN component |
| `rectifier-can/*.yaml` | parameterized per-unit CAN receive handlers |

## v4 display architecture

Version 4 replaces the previous immediate-mode TFT renderer with **ESPHome LVGL** while keeping charger/CAN/blackstart behavior unchanged. `display.yaml` is intentionally only an aggregator. Hardware transport, visual styling and screen logic are separated so they can evolve independently.

The ILI9488 is configured as a 480×320 RGB565 panel. LVGL rotates the logical canvas by 90° for the default **320×480 portrait dashboard**. Set `display_rotation` to `0` for landscape. The ESP32-S3 N16R8 has 8 MB PSRAM, so LVGL uses a **100% 16-bit RGB565 framebuffer**. All dashboard containers explicitly disable scrolling and scrollbars.

The portrait dashboard contains a header with date/time, firmware version and charger state, AC/DC summary cards, per-rectifier status, local encoder setpoints, thermal/efficiency information, network diagnostics and the local START/STOP reminder. The TFT header and `esphome.project.version` both consume `${firmware_version}` from `version.yaml`, so the version is maintained in exactly one place.

## Rectifier unit template

`rectifier-unit.yaml` is included three times with `ru_unit` set to `1`, `2` and `3`. Public IDs and entity names remain stable, for example `dc_voltage_1`, `output_temperature_1`, `can_com_ok_1` and `on_button_1`.

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

## Change discipline

Preserve public ESPHome IDs/entity names, CAN identifiers/payloads, protocol scaling, timing/order, lifecycle transitions, requested/applied current semantics, thermal thresholds and blackstart safety unless a change explicitly targets them.

Validate meaningful changes with:

```text
git diff --check
esphome config r4875g1-3phase-charger.yaml
esphome compile r4875g1-3phase-charger.yaml
```

For display changes, also verify the physical ILI9488 because panel rotation, font rendering and RGB565 appearance are hardware-visible concerns.

## Fan terminology

Two independent fan domains exist: external/chassis fans are GPIO-controlled through `cooling.yaml`; internal R4875G1 fans are controlled and read through Huawei CAN commands. Documentation and comments must keep these domains distinct.

## Release status

Firmware **4.0.4** is the current baseline on `main`. Version 4 introduces the LVGL display architecture; charger control, CAN recovery and blackstart behavior continue from the validated v3 baseline unless explicitly documented otherwise.
