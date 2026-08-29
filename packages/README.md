# Firmware package architecture

The `packages/` directory is the modular source-of-truth for the ESPHome firmware assembled by `../r4875g1-3phase-charger.yaml`.

## Ownership rules

| File | Owns | Must not own |
|---|---|---|
| `core.yaml` | ESP32 platform/framework and network/API/MQTT/web/OTA/time services | charger protocol or per-unit rectifier logic |
| `hardware.yaml` | shared I²C and SPI bus definitions | CAN protocol semantics |
| `display.yaml` | TFT, fonts, colors, display/backlight behavior | rectifier state machines |
| `cooling.yaml` | external chassis fan enable/PWM/tach | Huawei internal fan protocol |
| `controls.yaml` | charger-wide setpoint numbers and broadcast/shared control buttons | repeated individual unit controls |
| `rectifier-unit.yaml` | one parameterized R4875G1 instance | cross-unit scheduling/aggregation |
| `rectifier-shared.yaml` | lifecycle/discovery orchestration, shared limits/scripts, schedulers, single physical CAN component, non-identical shared protocol logic | repeated identical unit entity definitions |
| `rectifier-can/*.yaml` | one parameterized CAN `on_frame` mapping per genuinely identical handler family | the physical `canbus:` component |

## Rectifier unit template

`rectifier-unit.yaml` is included three times from the main YAML:

```yaml
rectifier_unit_1: !include
  file: packages/rectifier-unit.yaml
  vars:
    ru_unit: "1"
```

Units 2 and 3 use the same file with `ru_unit: "2"` and `ru_unit: "3"` respectively.

The template intentionally preserves the existing public IDs and entity names after substitution, such as:

```text
dc_voltage_1
output_temperature_1
can_com_ok_1
on_button_1
```

This protects Home Assistant entities, display references, MQTT-facing behavior and internal script references from an architecture-only refactor.

## CAN handler templates

ESPHome validates each `esp32_can` component before package merging, so the physical CAN component is defined exactly once in `rectifier-shared.yaml`.

Repeated RX handlers are instead parameterized as individual mappings and included inside that component's `on_frame:` list:

```yaml
- !include
    file: rectifier-can/cyclic-telemetry.yaml
    vars:
      ru_unit: "1"
```

Current handler templates:

- `property-start.yaml` — property START/DATA frames (`0x108xD27F`)
- `property-end.yaml` — property END parsing (`0x108xD27E`)
- `cyclic-telemetry.yaml` — normal telemetry/heartbeat (`0x108x407F`)
- `fan-telemetry.yaml` — internal Huawei fan telemetry (`0x108x827E`)
- `address-data.yaml` — shelf/slot addressing (`0x108x507E`)
- `power-state.yaml` — alternate current + ON/OFF/ERROR (`0x100x117E`)

The maximum-current capability handlers (`0x1081507F`, `0x1082507F`, `0x1083507F`) remain explicit in `rectifier-shared.yaml`. Each publishes its own capability/scaling diagnostic. Shared `effective_dc_current_limit` and `current_scaling_factor` are calculated centrally from only currently CAN-reachable units, with a 50 A failsafe whenever a reachable capability is unknown.

## What remains shared on purpose

Do not move code into the unit template merely because it references Unit 1/2/3. These operations describe the charger as a coordinated three-unit system and should stay explicit unless there is a strong functional reason to redesign them:

- lifecycle state coordination
- serialized discovery queue
- CAN-aware capability comparison, 50 A failsafe ceiling and shared command scaling
- staged shared thermal derating
- blackstart coordination and safety checks
- slow round-robin offline probing
- Single-Shot offline reconnect transport
- TWAI BUS_OFF recovery
- fixed fast-poll cadence and inter-unit timing
- aggregate AC/DC power and charger-wide diagnostics

## Change discipline

For architecture-only changes, preserve:

- existing ESPHome IDs and entity names
- CAN identifiers and payloads
- protocol scaling
- timing constants and poll order
- lifecycle transitions
- requested/applied current semantics
- thermal thresholds and lockout behavior
- blackstart safety conditions

Validate meaningful changes with at least:

```text
git diff --check
esphome config r4875g1-3phase-charger.yaml
esphome compile r4875g1-3phase-charger.yaml
```

For structural refactors, also compare the resolved configuration (`esphome config ... --no-defaults`) against the last known-good baseline and verify the entity/ID/CAN inventory.


## Root-level assembled entities

`../r4875g1-3phase-charger.yaml` intentionally retains the project-wide substitutions/package assembly and boot sequence plus cross-package entities such as controller diagnostics, AHT10 compartment data, local encoder input, aggregate charger telemetry, the physical encoder button, capability-mismatch diagnostic and network/device text diagnostics. These are shared assembled-device concerns rather than one rectifier instance.

## Release status

Firmware version **3.0.8** is the current modular baseline on `main`. Release tags are managed separately from normal firmware commits.


## Fan terminology

The project has two independent fan-control domains:

- **External/chassis fans** are GPIO-controlled in `cooling.yaml` through `Cooling Fan Power`, shared 25 kHz PWM and three tachometer inputs.
- **Internal R4875G1 fans** are controlled/read through Huawei CAN commands and telemetry in `controls.yaml`, `rectifier-unit.yaml` and the CAN handler packages.

Comments and entity descriptions must keep those two domains distinct.
