# Home Assistant Charger Entity Contract

## Status

Draft contract for the first Home Assistant integration generation.

This document defines the semantic interface between the R4875G1 Charger Controller firmware and the planned Home Assistant custom integration/dashboard.

It does not define Python or frontend implementation details beyond what is required to keep the interface stable.

The current V6.2.0 firmware is used as the source inventory for Contract 1.

Contract 1 should be considered formally implemented only after the Charger Controller firmware exposes an explicit Home Assistant contract identifier as described in this document.

## 1. Purpose

The Home Assistant custom integration must be able to identify one compatible Charger Controller and resolve its Home Assistant entities without requiring the user to enter individual entity IDs.

The frontend must consume stable semantic roles rather than installation-specific Home Assistant entity IDs.

Conceptually:

```text
Home Assistant entity
        |
        v
Custom Integration
        |
        | resolves
        v
Semantic Role
        |
        v
Dashboard / Custom Card
```

Example:

```text
sensor.hg_dg_technik_charger_combined_dc_power_all_units

                    becomes

charger.dc.power
```

The semantic role is stable even if the Home Assistant entity ID is renamed by the user.

## 2. Contract Principles

The following principles are normative for Contract 1.

1. The Charger Controller remains authoritative for charger operation and safety.
2. The Home Assistant integration does not implement CAN logic, START eligibility, lifecycle decisions, thermal protection or capability limiting.
3. The Home Assistant integration should not create duplicate telemetry entities merely to rename existing ESPHome entities.
4. The frontend consumes semantic roles, not hard-coded entity IDs.
5. Entity renames in Home Assistant must not invalidate an already configured Charger Instance.
6. Missing data must remain distinguishable from a valid zero value.
7. One integration config entry represents exactly one Charger Controller instance.
8. Multiple Charger Controller instances must be supported.
9. Optional installation context such as the solar battery bank is outside the core charger contract.
10. The current Remote HMI entity-prefix map is an inventory/reference, not the long-term Home Assistant discovery mechanism.
11. The Home Assistant solution must not become a dependency of local charger operation or blackstart.
12. Contract compatibility is independent from the normal firmware version.

## 3. Contract Identity

### 3.1 Firmware Project Identity

The current Charger Controller firmware declares:

```text
ESPHome project name:
anwa.r4875-charger
```

The Remote HMI uses a different project identity:

```text
anwa.r4875-remote-hmi
```

The Home Assistant integration must only create a Charger Instance for the Charger Controller.

ESPHome project metadata should be used as one discovery signal where Home Assistant exposes it reliably.

### 3.2 Contract Version

A dedicated contract version must be added to the Charger Controller firmware before Contract 1 is considered production-ready.

Recommended semantic value:

```text
1
```

Recommended Home Assistant-facing entity:

```text
Name:
R4875G1 Charger Contract

Semantic role:
metadata.contract_version

Expected state:
1
```

This entity should be diagnostic and read-only.

The exact ESPHome implementation belongs to a later firmware change.

### 3.3 Firmware Version

Firmware version and contract version are different concepts.

Example:

```text
Firmware version:        6.2.0
HA charger contract:     1
```

Firmware may advance while remaining compatible with Contract 1.

The Home Assistant integration must not infer contract compatibility from firmware version ranges when an explicit contract version is available.

### 3.4 Role Metadata

A separate role entity is not required for Contract 1 because the Charger Controller and Remote HMI already have distinct ESPHome project names.

If practical Home Assistant discovery cannot reliably access ESPHome project metadata, a future explicit role marker may be added without changing the semantic telemetry contract.

## 4. Semantic Role Naming

Semantic roles use lowercase dot-separated identifiers.

Examples:

```text
charger.dc.power
charger.command.start
rectifier.1.dc.current
cooling.compartment.temperature
system.controller_battery.soc
```

Rules:

- `charger.*` is charger-wide state or control.
- `rectifier.<n>.*` is one physical rectifier, with `n` in `1..3`.
- `cooling.*` is charger-side cooling/environment state.
- `system.*` is Charger Controller diagnostic state.
- `metadata.*` describes interface identity/compatibility.
- `external.*` is optional Home Assistant context not owned by the Charger Controller.

Role names are part of the public Home Assistant charger contract.

Changing the meaning of an existing role incompatibly requires a new contract version.

## 5. Role Classification

Contract roles use four classifications.

### 5.1 Required

A required role is necessary to create a fully compatible Charger Instance.

If a required role cannot be resolved unambiguously, the selected device is not Contract-1 compatible.

### 5.2 Optional Capability

An optional role enables additional UI or diagnostics.

A missing optional role must not invalidate the Charger Instance.

The instance may report `DEGRADED` if a user-visible optional feature is expected but unavailable.

### 5.3 Command

A command role maps to an existing Home Assistant controllable entity.

The integration resolves the entity but does not implement the underlying operation.

### 5.4 External Source

An external-source role belongs to another Home Assistant device/integration and is not part of Charger Controller compatibility.

Battery-bank telemetry is the first Contract-1 external source family.

## 6. Entity Resolution Model

### 6.1 Setup

The config flow asks the user to select one Charger Controller device.

The integration then inspects Home Assistant registry entries belonging to that device.

The user must not be asked to enter a charger entity prefix during normal setup.

### 6.2 Discovery Signals

Contract-1 discovery may use:

- selected Home Assistant device
- ESPHome platform ownership
- ESPHome project identity
- explicit `metadata.contract_version`
- entity domain
- entity registry metadata
- stable ESPHome entity identity
- expected current source names as compatibility evidence

No single editable Home Assistant entity ID should be treated as the permanent identity of a semantic role.

### 6.3 Stored Mapping

After initial resolution, each semantic role should be associated with stable entity-registry identity.

The implementation should prefer registry entry identity/unique identity over the mutable user-facing `entity_id`.

The integration must listen for entity-registry updates so a renamed entity continues to resolve to the same semantic role.

### 6.4 Ambiguity

If two entities on the selected device could satisfy the same required semantic role, setup must not guess silently.

The config flow should report the ambiguous role and require resolution or reject the device.

### 6.5 Missing Entities

Missing required role:

```text
Charger Instance -> INCOMPATIBLE
```

Missing optional role:

```text
Charger Instance -> compatible
optional capability -> unavailable
```

Unavailable runtime state is different from a missing entity mapping.

## 7. Core Charger Roles

The following roles define the charger-wide state used by the current V6 HMI.

| Semantic role | Class | HA domain | Current ESPHome name | Current firmware ID | Unit |
| --- | --- | --- | --- | --- | --- |
| `charger.ac.power` | Required | `sensor` | Combined AC Power All Units | `combined_ac_power` | kW |
| `charger.ac.voltage` | Required | `sensor` | Average AC Voltage All Units | `average_ac_voltage` | V |
| `charger.ac.current` | Required | `sensor` | Average AC Current All Units | `average_ac_current` | A |
| `charger.ac.current_limit` | Required/Command | `number` | Set AC Current Limit | `set_ac_current_limit` | A |
| `charger.dc.power` | Required | `sensor` | Combined DC Power All Units | `combined_dc_power` | kW |
| `charger.dc.voltage` | Required | `sensor` | Average DC Voltage All Units | `average_dc_voltage` | V |
| `charger.dc.current` | Required | `sensor` | Combined DC Current All Units | `combined_dc_current` | A |
| `charger.dc.voltage_setpoint` | Required/Command | `number` | Set DC Voltage Limit | `set_dc_voltage_limit` | V |
| `charger.dc.sum_power_setpoint` | Required/Command | `number` | Set DC Sum Power | `set_dc_sum_power` | kW |
| `charger.fallback.voltage_setpoint` | Required/Command | `number` | Set DC Voltage Limit Fallback | `set_dc_voltage_limit_fallback` | V |
| `charger.fallback.current_setpoint` | Required/Command | `number` | Set DC Current Limit Fallback | `set_dc_current_limit_fallback` | A |
| `charger.available_units` | Required | `sensor` | Available Units | `available_units` | count |
| `charger.running_units` | Required | `sensor` | Running Units | `running_units` | count |
| `charger.highest_output_temperature` | Required | `sensor` | Highest Output Temperature All Units | `highest_output_temperature` | °C |
| `charger.conversion_efficiency` | Required | `sensor` | Conversion Efficiency All Units | `conversion_efficiency` | % |
| `charger.command.start` | Command/Required | `button` | Turn On All Units | `on_button_all` | — |
| `charger.command.stop` | Command/Required | `button` | Turn Off All Units | `off_button_all` | — |

The current Remote HMI prefix map already consumes the same public Home Assistant entities for these functions.

## 8. Charger-Wide Optional Roles

The following existing firmware entities are useful but are not required for the initial HMI-compatible core.

| Semantic role | Class | HA domain | Current ESPHome name | Current firmware ID | Unit |
| --- | --- | --- | --- | --- | --- |
| `charger.dc.current_setpoint` | Optional/Command | `number` | Set DC Current Limit | `set_dc_current_limit` | A |
| `charger.dc.current_limit_effective` | Optional | `sensor` | Effective DC Current Limit | `effective_dc_current_limit_sensor` | A |
| `charger.dc.current_limit_thermal` | Optional | `sensor` | Thermal DC Current Limit | `thermal_dc_current_limit_sensor` | A |
| `charger.dc.current_limit_applied` | Optional | `sensor` | Applied DC Current Limit | `applied_dc_current_limit_sensor` | A |
| `charger.internal_fan.minimum_duty_setpoint` | Optional/Command | `number` | Set Fan Minimum Speed | `set_fan_min_speed` | % |
| `charger.internal_fan.command.auto_all` | Optional/Command | `button` | Set Fan Auto Mode All Units | `fan_auto_mode_button_all` | — |
| `charger.internal_fan.command.full_all` | Optional/Command | `button` | Set Fan Full Speed All Units | `fan_full_speed_button_all` | — |
| `charger.command.discover_rectifiers` | Optional/Command | `button` | Discover Rectifier Units | `setup_button` | — |
| `charger.energy.ac_today` | Optional | `sensor` | AC Energy Today | current aggregate sensor | kWh |
| `charger.energy.dc_today` | Optional | `sensor` | DC Energy Today | current aggregate sensor | kWh |
| `charger.capability_mismatch` | Optional | `binary_sensor` | Rectifier Capability Mismatch | `rectifier_capability_mismatch` | boolean |

These roles can support an advanced diagnostics/settings section without being necessary for the first dashboard release.

## 9. Setpoint Ranges

The frontend must not duplicate numeric limits as independent JavaScript constants when the Home Assistant `number` entity already exposes its active minimum, maximum and step.

The current V6 UI contract uses:

| Setpoint | Current minimum | Current maximum | Current step |
| --- | ---: | ---: | ---: |
| AC current limit | 0.0 A | 21.0 A | 0.1 A |
| DC voltage | 49.0 V | 58.0 V | 0.1 V |
| DC sum power | 0.1 kW | 12.0 kW | 0.1 kW |
| Fallback DC current | 1.0 A | 75.0 A | 0.1 A |
| Fallback DC voltage | 49.0 V | 58.0 V | 0.1 V |

These values document the current firmware behavior.

The Home Assistant frontend should read current number-entity constraints at runtime.

## 10. Rectifier Role Template

Contract 1 defines three rectifier instances.

The same semantic role template is instantiated for:

```text
rectifier.1.*
rectifier.2.*
rectifier.3.*
```

### 10.1 Required Rectifier State and Telemetry

For every unit `n` in `1..3`:

| Semantic role template | Class | HA domain | Current Home Assistant object-name pattern | Unit |
| --- | --- | --- | --- | --- |
| `rectifier.n.connected` | Required | `binary_sensor` | CAN Communication Unit n | boolean |
| `rectifier.n.lifecycle` | Required | `sensor` | Control State Unit n | state |
| `rectifier.n.power_state` | Required | `sensor` | Power State Unit n | state |
| `rectifier.n.thermal_state` | Required | `sensor` | Thermal State Unit n | state |
| `rectifier.n.ac.voltage` | Required | `sensor` | AC Voltage Unit n | V |
| `rectifier.n.ac.current` | Required | `sensor` | AC Current Unit n | A |
| `rectifier.n.ac.power` | Required | `sensor` | AC Power Unit n | W/kW as published |
| `rectifier.n.ac.frequency` | Required | `sensor` | AC Frequency Unit n | Hz |
| `rectifier.n.dc.voltage` | Required | `sensor` | DC Voltage Unit n | V |
| `rectifier.n.dc.current` | Required | `sensor` | DC Current Unit n | A |
| `rectifier.n.dc.power` | Required | `sensor` | DC Power Unit n | W/kW as published |
| `rectifier.n.dc.current_setpoint_reported` | Required | `sensor` | Max DC Current Setpoint Unit n | A |
| `rectifier.n.temperature.input` | Required | `sensor` | Input Temperature Unit n | °C |
| `rectifier.n.temperature.output` | Required | `sensor` | Output Temperature Unit n | °C |
| `rectifier.n.fan.rpm` | Required | `sensor` | Fan RPM Unit n | RPM |
| `rectifier.n.fan.minimum_duty` | Required | `sensor` | Fan Minimum Duty Unit n | % |
| `rectifier.n.fan.target_duty` | Required | `sensor` | Fan Duty Target Unit n | % |
| `rectifier.n.max_current_capability` | Required | `sensor` | Max Current Capability Unit n | A |
| `rectifier.n.operating_hours` | Required | `sensor` | Operating Hours Unit n | h |

These roles correspond to the current V6 Rectifiers and Rectifier Detail presentation.

### 10.2 Required Rectifier Commands

For every unit `n` in `1..3`:

| Semantic role template | Class | HA domain | Current object-name pattern |
| --- | --- | --- | --- |
| `rectifier.n.command.start` | Command/Required | `button` | Turn On Unit n |
| `rectifier.n.command.stop` | Command/Required | `button` | Turn Off Unit n |

### 10.3 Optional Rectifier Commands

For every unit `n` in `1..3`:

| Semantic role template | Class | HA domain | Current object-name pattern |
| --- | --- | --- | --- |
| `rectifier.n.fan.command.auto` | Optional/Command | `button` | Set Fan Auto Mode Unit n |
| `rectifier.n.fan.command.full` | Optional/Command | `button` | Set Fan Full Speed Unit n |

The integration resolves each unit independently but Contract 1 requires all three unit namespaces to exist because the firmware product is defined as a three-rectifier charger.

A physically disconnected rectifier is represented by runtime state, not by removing its entity mappings.

## 11. Rectifier State Semantics

### 11.1 Lifecycle

Expected lifecycle values:

```text
OFFLINE
DISCOVERING
ONLINE
```

Unknown/unavailable Home Assistant state is not equivalent to `OFFLINE`.

### 11.2 Power State

Expected power-state values include:

```text
ON
OFF
UNKNOWN
ERROR
```

The frontend must not infer power state from current or power telemetry when the authoritative power-state entity exists.

### 11.3 Thermal State

Expected thermal-state values:

```text
NORMAL
WARNING_1
WARNING_2
LOCKOUT
```

The frontend displays this state but does not reproduce the threshold logic.

### 11.4 Connectivity

`rectifier.n.connected` represents current CAN communication state.

A false state and an unavailable entity are different conditions.

## 12. Cooling Environment Roles

The current shared HMI consumes these charger-side environment roles.

| Semantic role | Class | HA domain | Current ESPHome name | Unit |
| --- | --- | --- | --- | --- |
| `cooling.compartment.temperature` | Required | `sensor` | Rectifier Compartment Temperature | °C |
| `cooling.compartment.humidity` | Required | `sensor` | Rectifier Compartment Humidity | % |
| `cooling.compartment.sea_level_pressure` | Required | `sensor` | Rectifier Compartment Sea Level Pressure | pressure |

These entities belong to the selected Charger Controller device.

## 13. External Cooling Capability

The Charger Controller exposes a richer external cooling interface than the current shared touchscreen Cooling page requires.

Contract 1 defines it as an optional capability group.

Capability identifier:

```text
external_cooling
```

Roles:

| Semantic role | Class | HA domain | Current ESPHome name | Unit |
| --- | --- | --- | --- | --- |
| `cooling.external.automatic` | Optional/Command | `switch` | Cooling Fan Automatic | boolean |
| `cooling.external.power` | Optional/Command | `switch` | Cooling Fan Power | boolean |
| `cooling.external.manual_pwm` | Optional/Command | `number` | Cooling Fan Manual PWM | % |
| `cooling.external.actual_pwm` | Optional | `sensor` | Cooling Fan PWM Actual | % |
| `cooling.external.controller_temperature` | Optional | `sensor` | Cooling Fan Controller Temperature | °C |
| `cooling.external.fan.1.rpm` | Optional | `sensor` | Cooling Fan 1 RPM | RPM |
| `cooling.external.fan.2.rpm` | Optional | `sensor` | Cooling Fan 2 RPM | RPM |
| `cooling.external.fan.3.rpm` | Optional | `sensor` | Cooling Fan 3 RPM | RPM |

The dashboard may initially present this capability as an advanced extension rather than changing the visual structure of the existing physical HMI.

The frontend must not derive charger safety state from these RPM values.

## 14. Charger Controller System Roles

The current firmware exposes target-local diagnostics.

These form an optional capability group:

```text
controller_diagnostics
```

### 14.1 Backup Battery

| Semantic role | Class | HA domain | Current ESPHome name | Unit |
| --- | --- | --- | --- | --- |
| `system.controller_battery.voltage` | Optional | `sensor` | Controller Battery Voltage | V |
| `system.controller_battery.soc` | Optional | `sensor` | Controller Battery State of Charge | % |

### 14.2 Runtime and Network Diagnostics

| Semantic role | Class | HA domain | Current ESPHome name | Unit |
| --- | --- | --- | --- | --- |
| `system.heap.free` | Optional | `sensor` | Heap Free | bytes |
| `system.heap.max_block` | Optional | `sensor` | Heap Max Block | bytes |
| `system.psram.free` | Optional | `sensor` | Free PSRAM | bytes |
| `system.loop_time` | Optional | `sensor` | Loop Time | runtime unit |
| `system.cpu.frequency` | Optional | `sensor` | CPU Frequency | MHz |
| `system.cpu.temperature` | Optional | `sensor` | Controller CPU Temperature | °C |
| `system.uptime` | Optional | `sensor` | Uptime | s |
| `system.wifi.rssi` | Optional | `sensor` | WiFi RSSI | dBm |
| `system.ip_address` | Optional | `text_sensor` | ESPHome WiFi IP address entity | address |
| `system.esphome_version` | Optional | `text_sensor` | ESPHome Version | text |
| `system.device_info` | Optional | `text_sensor` | Device Info | text |
| `system.reset_reason` | Optional | `text_sensor` | Reset Reason | text |

The exact Home Assistant object ID for unnamed `wifi_info.ip_address` is implementation-generated and must be resolved through registry metadata rather than hard-coded.

## 15. Metadata Roles

Contract 1 reserves these roles:

| Semantic role | Class | Source |
| --- | --- | --- |
| `metadata.contract_version` | Required | explicit future Charger Controller diagnostic entity |
| `metadata.firmware_version` | Required descriptor field | ESPHome project/device metadata, or explicit entity if required |
| `metadata.project_name` | Required descriptor field | ESPHome project metadata |
| `metadata.display_name` | Required descriptor field | Home Assistant device/config-entry metadata |

Expected project name:

```text
anwa.r4875-charger
```

Expected Contract-1 version:

```text
1
```

The implementation must verify during prototyping which ESPHome project fields are available through Home Assistant's device/config-entry metadata.

If firmware version or project identity cannot be obtained reliably through the registry/API, explicit read-only firmware metadata entities should be added before production release.

## 16. Command Transport

Contract 1 does not require custom Home Assistant proxy services.

The preferred command path is:

```text
Frontend
   |
   v
resolved semantic role
   |
   v
current Home Assistant entity_id
   |
   v
normal HA domain service
   |
   v
existing ESPHome entity
   |
   v
Charger Controller
```

Examples:

```text
charger.command.start
    -> button entity
    -> button.press

charger.dc.voltage_setpoint
    -> number entity
    -> number.set_value

cooling.external.automatic
    -> switch entity
    -> switch.turn_on / switch.turn_off
```

This preserves the existing Charger Controller authority and avoids an unnecessary second control API.

The backend integration may provide helper APIs to resolve semantic roles, but it should not proxy or reinterpret control behavior unless a future requirement clearly justifies it.

## 17. Command Confirmation

The frontend must not treat a successful Home Assistant service call as proof that the charger reached the requested operational state.

Example START flow:

```text
User presses START
      |
      v
button.press succeeds
      |
      v
UI shows request pending
      |
      v
wait for authoritative charger state
      |
      +--> running_units > 0 / rectifier power states change
      |       -> request resolved
      |
      `--> timeout / offline / no accepted state transition
              -> request not confirmed
```

The frontend may show a pending request but must not optimistically publish charger operational state.

STOP follows the same presentation model even though Controller STOP behavior is intentionally unrestricted.

## 18. Runtime Availability Semantics

Entity mapping and entity runtime availability are separate concerns.

### 18.1 Mapped and Available

The entity exists in the registry and currently has a usable state.

### 18.2 Mapped but Unavailable

The entity mapping is valid but Home Assistant reports:

```text
unavailable
unknown
```

or the state is otherwise invalid for the role.

This is a runtime availability problem, not a contract-resolution problem.

### 18.3 Missing Mapping

No entity can satisfy the semantic role.

For required roles, this is a compatibility problem.

### 18.4 Numeric Zero

A valid state of zero must remain zero.

It must never be used as the fallback representation for unavailable numeric telemetry.

## 19. Charger Instance Availability

The Home Assistant integration should expose one derived compatibility/runtime state to the frontend.

Recommended states:

```text
OK
DEGRADED
OFFLINE
INCOMPATIBLE
```

### OK

- Contract identity valid.
- All required semantic roles resolved.
- Core authoritative charger state currently available.

### DEGRADED

- Contract identity valid.
- All required semantic roles resolved.
- One or more optional capabilities are unavailable or incomplete.

### OFFLINE

- Contract identity and mappings are valid.
- Charger Controller authoritative state is currently unavailable.

### INCOMPATIBLE

Any of:

- unsupported contract version
- wrong ESPHome project/device
- required semantic role missing
- required semantic role ambiguous
- required entity has an incompatible domain/type

The frontend should consume this instance state consistently.

## 20. Capability Descriptor

The backend should produce explicit feature flags instead of forcing the frontend to infer features from random entity presence.

Initial capability identifiers:

```text
core_charger
rectifier_detail
cooling_environment
external_cooling
controller_diagnostics
external_battery_bank
history
```

Expected baseline:

```text
core_charger:            required
rectifier_detail:        required
cooling_environment:     required
external_cooling:        optional
controller_diagnostics:  optional
external_battery_bank:   optional external source
history:                 Home Assistant capability
```

The descriptor should also list missing optional roles for diagnostics.

## 21. External Battery Source Contract

The Battery page is intentionally outside the core Charger Controller entity contract.

The current ESPHome HMI imports the battery data from Home Assistant. The new Home Assistant dashboard should consume the original Home Assistant battery entities directly instead of routing them through the Charger Controller.

External semantic namespace:

```text
external.battery_bank.*
external.battery.1.*
external.battery.2.*
external.battery.3.*
external.battery.4.*
```

### 21.1 Aggregate Battery Bank Roles

| Semantic role | Class | Unit/type |
| --- | --- | --- |
| `external.battery_bank.voltage` | External | V |
| `external.battery_bank.current` | External | A |
| `external.battery_bank.power` | External | kW |
| `external.battery_bank.soc` | External | % |
| `external.battery_bank.temperature` | External | °C |
| `external.battery_bank.state` | External | text |

### 21.2 Per-Battery Roles

For `n` in `1..4`:

| Semantic role template | Class | Unit/type |
| --- | --- | --- |
| `external.battery.n.voltage` | External | V |
| `external.battery.n.current` | External | A |
| `external.battery.n.power` | External | kW |
| `external.battery.n.soc` | External | % |
| `external.battery.n.temperature` | External | °C |
| `external.battery.n.cell_drift` | External | mV |
| `external.battery.n.warning` | External | boolean with unavailable preserved |
| `external.battery.n.fault` | External | boolean with unavailable preserved |

### 21.3 Discovery

Battery source discovery is not part of Charger Controller compatibility.

The integration should:

1. attempt automatic discovery when an unambiguous supported source pattern exists
2. associate the resolved source set with the Charger Instance
3. ask the user only when discovery is ambiguous or incomplete
4. allow the battery capability to remain unconfigured

No battery role may participate in charger START eligibility or charger safety.

### 21.4 Current Installation Mapping

The current firmware contains installation-specific battery entity mappings.

Those mappings are useful as a development reference only.

They must not become hard-coded defaults in the general Home Assistant frontend.

## 22. History and Trends Contract

The Home Assistant dashboard should use Home Assistant history/statistics for browser-side Trends.

Required trend semantic series:

```text
charger.dc.power
charger.dc.current
charger.dc.voltage
charger.highest_output_temperature
cooling.compartment.temperature
```

Default visual history window:

```text
60 minutes
```

The browser history source is Home Assistant, not the Controller's in-memory LVGL ring buffer.

Unavailable samples must remain gaps.

Contract 1 does not require firmware entities representing the LVGL ring-buffer contents.

## 23. Current Home Assistant Object Patterns

The current V6.2.0 Remote HMI maps entities by a configurable prefix.

Example current patterns:

```text
sensor.<prefix>_combined_ac_power_all_units
sensor.<prefix>_average_ac_voltage_all_units
sensor.<prefix>_average_ac_current_all_units
number.<prefix>_set_ac_current_limit

sensor.<prefix>_combined_dc_power_all_units
sensor.<prefix>_average_dc_voltage_all_units
sensor.<prefix>_combined_dc_current_all_units
number.<prefix>_set_dc_voltage_limit
number.<prefix>_set_dc_sum_power

sensor.<prefix>_available_units
sensor.<prefix>_running_units

button.<prefix>_turn_on_all_units
button.<prefix>_turn_off_all_units
```

Per-unit examples:

```text
binary_sensor.<prefix>_can_communication_unit_1
sensor.<prefix>_control_state_unit_1
sensor.<prefix>_power_state_unit_1
sensor.<prefix>_dc_current_unit_1
button.<prefix>_turn_on_unit_1
button.<prefix>_turn_off_unit_1
```

These patterns are compatibility evidence and are useful during initial resolver development.

They are not normative persistent identifiers.

The new integration must not store `<prefix>` as the primary long-term contract identity.

## 24. Backend Charger Instance Descriptor

The backend must expose a resolved Charger Instance descriptor to the frontend.

Conceptual shape:

```text
instance
  id
  display_name

metadata
  project_name
  firmware_version
  contract_version

status
  compatibility
  availability

capabilities
  core_charger
  rectifier_detail
  cooling_environment
  external_cooling
  controller_diagnostics
  external_battery_bank
  history

roles
  charger.ac.power
  charger.dc.power
  ...
  rectifier.1.lifecycle
  ...

missing_optional_roles
  ...

external_sources
  battery_bank
```

Each resolved role needs enough information for the frontend to:

- locate the current Home Assistant entity
- understand its domain
- call the correct standard Home Assistant service when controllable
- subscribe to state changes

The exact WebSocket JSON schema is intentionally deferred to implementation design.

## 25. Frontend Dependency Rules

The frontend must not:

- search Home Assistant entities by prefix itself
- reconstruct entity IDs from device names
- contain installation-specific entity IDs
- infer START eligibility
- infer contract compatibility from firmware version
- assume unavailable numeric values are zero
- directly inspect private Python integration storage

The frontend should receive all role resolution and capability information from the custom integration.

## 26. Compatibility Rules

### 26.1 Contract-Major Compatibility

Contract version `1` represents the first stable semantic interface.

Additive optional roles do not require Contract 2.

Adding a new required role to Contract 1 after release should be avoided because it would invalidate previously compatible firmware.

### 26.2 Incompatible Changes

Examples requiring a new contract version include:

- changing the meaning of an existing semantic role
- changing a required role to an incompatible entity type
- removing a required role
- fundamentally changing rectifier indexing
- changing command semantics in a way the existing frontend cannot safely use

### 26.3 Compatible Changes

Examples that can remain Contract 1:

- adding optional telemetry
- adding optional diagnostics
- adding a new optional capability group
- changing firmware internal IDs while preserving HA-facing entity identity
- user-renaming Home Assistant entity IDs
- changing frontend layout without changing semantic meaning

## 27. Contract-1 Firmware Preparation

Before implementing the production Home Assistant integration, the Charger Controller firmware should receive one small compatibility-oriented update.

Required addition:

```text
metadata.contract_version
```

Recommended visible name:

```text
R4875G1 Charger Contract
```

Recommended state:

```text
1
```

Recommended category:

```text
diagnostic
```

This should be the only new firmware behavior required solely to bootstrap Contract 1 unless implementation testing proves that explicit firmware-version/project metadata entities are also necessary.

The firmware project identity already distinguishes:

```text
anwa.r4875-charger
anwa.r4875-remote-hmi
```

so no duplicate role marker should be added without a demonstrated need.

## 28. Contract-1 Resolver Acceptance Criteria

A Contract-1 backend resolver is acceptable when all of the following are true:

1. The user selects only the Charger Controller device during normal setup.
2. No entity prefix is required.
3. All required charger roles resolve automatically.
4. All three rectifier namespaces resolve automatically.
5. Charger-wide START/STOP commands resolve to the existing buttons.
6. Per-unit START/STOP commands resolve to the existing buttons.
7. Renaming a resolved Home Assistant entity does not break the configured Charger Instance.
8. Restarting Home Assistant preserves the same semantic mapping.
9. Temporarily unavailable entities produce `OFFLINE`/unavailable state rather than remapping failure.
10. Selecting the Remote HMI instead of the Charger Controller is rejected.
11. A missing required role produces a clear incompatible-device diagnostic.
12. Missing optional cooling/system roles do not invalidate the core charger.
13. No duplicate telemetry entities are created by the integration.
14. No charger safety decision is implemented in Python or JavaScript.
15. Multiple Charger Controller devices can be configured as separate instances.

## 29. Initial Implementation Scope

The first implementation should target these capability groups:

```text
Contract identity
Core charger
Rectifier detail
Cooling environment
Controller diagnostics
```

Commands included in the first implementation:

```text
charger START/STOP
AC current setpoint
DC voltage + sum-power setpoints
fallback voltage/current
per-rectifier START/STOP
```

Second-stage optional features:

```text
external cooling controls
battery source discovery
advanced diagnostics/actions
extended trend ranges
per-rectifier fan-mode controls
```

This keeps the first backend useful while avoiding unnecessary breadth before the instance resolver and frontend contract have been proven.

## 30. Source-of-Truth Relationship

The sources of truth are intentionally separated.

```text
Firmware behavior
    -> ESPHome source files

Home Assistant semantic interface
    -> HomeAssistant/ENTITY_CONTRACT.md

Overall HA architecture
    -> HomeAssistant/ARCHITECTURE.md

Frontend visual behavior
    -> future HomeAssistant/UI_SPEC.md

HA release acceptance
    -> future HomeAssistant/TEST_PLAN.md
```

When firmware changes an HA-facing required role, this contract must be reviewed in the same development step.

When the contract changes incompatibly, the contract version must change explicitly.

## 31. Next Step

After this document is accepted:

1. add the explicit Contract-1 metadata marker to the Charger Controller firmware in a small isolated firmware change
2. validate how ESPHome project metadata, entity unique identity and entity-registry metadata are exposed by the current Home Assistant version
3. freeze the exact Contract-1 resolver rules
4. create the dedicated Home Assistant backend repository
5. implement only config flow, device validation, semantic resolution and diagnostics first
6. prove rename safety and restart persistence
7. only then begin the production dashboard frontend

The frontend should not be started by hard-coding the current entity prefix as a shortcut around the resolver.
