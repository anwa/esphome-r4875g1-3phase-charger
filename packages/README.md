# Firmware Package Architecture

This directory contains the modular ESPHome implementation of the three-phase Huawei R4875G1 charger controller.

The V6 architecture contains two ESPHome root configurations:

```text
../r4875g1-3phase-charger.yaml
../r4875g1-remote-hmi.yaml
```

r4875g1-3phase-charger.yaml assembles the locally attached Charger Controller.

r4875g1-remote-hmi.yaml assembles the Remote HMI target without charger-side CAN or external peripherals.

For project-level hardware, operation and safety documentation, see:

```text
../README.md
```

For detailed rectifier lifecycle and control-flow documentation, see:

```text
../R4875G1_CONTROL_FLOWS.md
```

The firmware version is intentionally not duplicated here.
`version.yaml` is the single source of truth.

---

## Package Structure

```text
packages/
├── version.yaml
│
├── shared/
│   ├── core.yaml
│   ├── hardware.yaml
│   └── ui-model.yaml
│
├── controller/
│   ├── hardware.yaml
│   ├── mqtt.yaml
│   └── ui-backend.yaml
│
├── remote-hmi/
│   ├── bootstrap-ui.yaml
│   └── ha-backend.yaml
│
├── controls.yaml
├── cooling.yaml
├── battery-bank.yaml
├── display.yaml
├── rectifier-shared.yaml
├── rectifier-unit.yaml
├── README.md
│
├── display/
│   ├── hardware.yaml
│   ├── theme.yaml
│   ├── ui.yaml
│   ├── header.yaml
│   ├── command-state.yaml
│   ├── controller-battery.yaml
│   ├── battery.yaml
│   ├── dashboard.yaml
│   ├── rectifiers.yaml
│   ├── rectifier-detail.yaml
│   ├── cooling.yaml
│   ├── system.yaml
│   ├── trends.yaml
│   │
│   └── pages/
│       ├── dashboard.yaml
│       ├── rectifiers.yaml
│       ├── rectifier-detail.yaml
│       ├── battery.yaml
│       ├── cooling.yaml
│       ├── system.yaml
│       └── trends.yaml
│
└── rectifier-can/
    ├── property-start.yaml
    ├── property-end.yaml
    ├── cyclic-telemetry.yaml
    ├── fan-telemetry.yaml
    ├── address-data.yaml
    └── power-state.yaml
```

---

## Ownership Principles

Package ownership is intentionally separated so that hardware, shared charger logic, per-unit state, display layout and periodic display updates remain independent.

The main ownership boundaries are:

```text
shared/core.yaml
    target-neutral ESP32-S3 platform and network services

shared/hardware.yaml
    target-neutral Waveshare board peripherals

shared/ui-model.yaml
    target-neutral state contract consumed by the HMI

controller/hardware.yaml
    Charger Controller buses and charger-side peripherals

controller/mqtt.yaml
    Charger Controller MQTT transport

controller/ui-backend.yaml
    publishes authoritative local charger state into the shared UI model

remote-hmi/bootstrap-ui.yaml
    temporary Remote HMI hardware-validation UI

remote-hmi/ha-backend.yaml
    imports authoritative Charger Controller state through Home Assistant

controls.yaml
    charger-wide user setpoints and controls

cooling.yaml
    external chassis cooling

battery-bank.yaml
    Home Assistant solar-battery telemetry import and availability state

display.yaml
    display package aggregation

rectifier-shared.yaml
    cross-unit lifecycle, safety and CAN scheduling

rectifier-unit.yaml
    parameterized per-unit state and telemetry

display/*.yaml
    persistent and page-specific display runtime

display/pages/*.yaml
    static LVGL page layouts

rectifier-can/*.yaml
    parameterized CAN receive fragments

```
A package SHOULD own one coherent responsibility and SHOULD NOT duplicate runtime state or hardware definitions owned elsewhere.

---

## `version.yaml`

`version.yaml` is the only source of truth for the firmware version.

The value is consumed by the firmware project metadata and user-interface components that display the current version.

Versioning policy is defined in:

```text
../rules/versioning.md
```

Documentation-only and repository-cleanup commits do not require a firmware version change unless runtime behavior also changes.

---

## `shared/core.yaml`

Owns target-neutral ESP32-S3 platform and network infrastructure shared by the Charger Controller and Remote HMI.

Responsibilities include:

- ESP32-S3 platform and framework configuration
- Flash and PSRAM configuration
- logging
- Wi-Fi
- ESPHome native API
- web server
- OTA
- time synchronization
- runtime diagnostics

Target-specific command and telemetry transports do not belong in this package.

---

## `shared/hardware.yaml`

Owns physical Waveshare ESP32-S3-Touch-LCD-7 hardware that is independent of the charger-side backend.

Responsibilities include:

- onboard I2C bus
- GT911 touchscreen
- CH422G onboard I/O expander
- controller backup-battery ADC and SOC estimate

This package contains board hardware that can be reused by multiple firmware targets without requiring charger-side peripherals.

---

## `shared/ui-model.yaml`

Owns the target-neutral runtime state consumed by shared HMI code.

The model isolates LVGL presentation from the source of charger data. Charger Controller and Remote HMI backends publish into the same model IDs so shared display code does not need target-specific telemetry paths.

---

## `controller/hardware.yaml`

Owns physical hardware that exists only on the Charger Controller.

Responsibilities include:

- dedicated charger-side external I2C bus
- MCP23017 external I/O expander
- backup rotary-encoder inputs
- USB/CAN routing selection
- ESP32-S3 TWAI / onboard CAN interface

---

## `controller/mqtt.yaml`

Owns the Charger Controller MQTT transport.

MQTT remains optional for charger operation and is independent from the native ESPHome API used by Home Assistant.

The Remote HMI does not require this package.

---

## `controller/ui-backend.yaml`

Owns translation from authoritative local Charger Controller runtime state into the shared UI model.

This backend does not own charger state itself. The existing controller runtime remains authoritative.

---

## `remote-hmi/bootstrap-ui.yaml`

Provides the temporary Remote HMI bootstrap and validation interface.

The page exposes local display, touch and backup-battery operation together with the first Home Assistant-backed charger-state indicators while the complete shared production HMI is being migrated.

---

## `remote-hmi/ha-backend.yaml`

Owns the Remote HMI Home Assistant transport.

It imports authoritative Charger Controller entities from Home Assistant and publishes them into the shared UI model. Shared LVGL code therefore consumes the same `ui_model_*` entities on both firmware targets.

Loss of the Home Assistant state-subscription connection invalidates Remote HMI charger state so stale values cannot appear as live telemetry.

---

## Charger Controller I2C Topology

The controller uses two independent physical I2C buses. The onboard bus is reserved for Waveshare peripherals, while external peripherals use a dedicated bus to avoid address collisions with the onboard CH422G.

```text
ESP32-S3
│
├── Onboard I2C bus
│   ├── SDA -> GPIO8
│   ├── SCL -> GPIO9
│   ├── CH422G
│   └── GT911 touchscreen
│
└── External I2C bus
    ├── SDA -> GPIO44
    ├── SCL -> GPIO43
    ├── MCP23017 @ 0x20
    ├── AHT10 @ 0x38
    └── EMC2101 @ 0x4C
```

The onboard I2C bus is configured in `shared/hardware.yaml`. The charger-side external I2C bus and MCP23017 are configured in `controller/hardware.yaml`. The AHT10 sensor remains configured in the root `r4875g1-3phase-charger.yaml`, while the EMC2101 fan controller is configured in `cooling.yaml`.

### MCP23017 Allocation

```text
GPA0 -> backup rotary encoder A
GPA1 -> backup rotary encoder B
GPA2 -> backup rotary encoder button
GPA3 -> external cooling-fan supply enable
GPA4 -> Cooling Fan 1 tachometer
GPA5 -> Cooling Fan 2 tachometer
```

The backup encoder inputs currently provide hardware entities only.
No charger-control or navigation actions are assigned to them in the current V6 firmware.

---

## `controls.yaml`

Owns charger-wide user-facing setpoints and controls.

This includes values such as:

- active DC voltage target
- charger power target
- fallback voltage
- fallback current
- charger-wide START/STOP controls

Shared controls SHOULD express user intent.

Safety limiting, capability limiting and per-unit CAN command transmission are implemented in the rectifier control packages rather than directly in
`controls.yaml`.

---

## `cooling.yaml`

Owns the external chassis cooling system.

This subsystem is separate from the internal fans built into the Huawei rectifiers.

Current external cooling hardware:

```text
MCP23017 GPA3 -> common fan-supply enable
MCP23017 GPA4 -> Cooling Fan 1 tachometer
MCP23017 GPA5 -> Cooling Fan 2 tachometer

EMC2101 PWM   -> common four-pin fan PWM
EMC2101 TACH  -> Cooling Fan 3 tachometer

AHT10         -> rear-compartment temperature and humidity
```

Responsibilities include:

- EMC2101 fan-controller configuration
- EMC2101 internal-temperature and PWM-duty telemetry
- common external fan PWM
- persistent manual PWM setpoint
- common fan-supply enable
- three independent RPM measurements
- automatic temperature-based cooling
- manual fan-power and PWM control

Automatic and manual PWM ownership is intentionally separated. Automatic mode writes the temperature-derived duty cycle directly to the EMC2101 output without modifying the stored manual PWM setpoint. Disabling automatic mode immediately applies the stored manual setpoint, and subsequent manual slider changes control the output directly.

`Cooling Fan PWM Actual` is the EMC2101 duty-cycle register readback and therefore represents the controller's programmed PWM setting rather than an independently measured waveform.

Cooling Fan 3 ventilates the rear rectifier compartment monitored by the AHT10.

Automatic cooling fails safe to enabled fan power and maximum PWM if the compartment temperature becomes unavailable.

---

## `battery-bank.yaml`

Owns Home Assistant telemetry import for the external solar battery bank.

The package centralizes all configurable Home Assistant entity mappings so display code does not contain installation-specific entity IDs.

Responsibilities include:

- aggregate battery-bank voltage, current, power, state of charge, temperature and operating state
- per-battery voltage, current, power, state of charge, temperature and cell drift
- per-battery warning and fault states
- power-unit normalization for imported battery telemetry
- Home Assistant connection and data-availability states

Warning and fault entities are intentionally imported as text so unavailable source data remains distinguishable from a genuine inactive warning or fault.

This package is monitoring-only and MUST NOT participate in charger control, CAN commands, lifecycle decisions or safety limits.

---

# Rectifier Architecture

The rectifier implementation is split into shared and parameterized packages.

```text
rectifier-shared.yaml
        │
        ├── shared lifecycle and safety state
        ├── discovery serialization
        ├── capability evaluation
        ├── thermal limiting
        ├── CAN scheduling
        └── charger-wide command routing

rectifier-unit.yaml
        │
        └── instantiated once for each rectifier

rectifier-can/*.yaml
        │
        └── parameterized CAN receive fragments
```

---

## `rectifier-shared.yaml`

Owns cross-unit state and behavior shared by all three rectifiers.

Major responsibilities include:

- rectifier lifecycle coordination
- communication reconciliation
- TWAI recovery handling
- serialized discovery
- low-rate OFFLINE probing
- high-rate ONLINE polling
- capability-aware current limiting
- shared protocol scaling
- thermal current limiting
- active setpoint routing
- blackstart START/STOP sequences
- periodic setpoint refresh
- local trend sampling

### Lifecycle

Each rectifier uses:

```text
OFFLINE
DISCOVERING
ONLINE
```

Normal cyclic and fan telemetry polling is restricted to `ONLINE` units.

`OFFLINE` units are probed sparsely so absent peers cannot continuously generate high-rate failed CAN transmissions.

### Shared Current Limit

The effective current ceiling is derived from currently reachable rectifiers.

If any reachable unit has an unknown maximum-current capability, the conservative fail-safe ceiling is used.

When all reachable capabilities are known, the lowest reachable capability becomes the shared hardware ceiling.

The thermal ceiling is applied independently.

Final CAN current commands therefore use the most restrictive relevant limit.

---

## `rectifier-unit.yaml`

Parameterized package instantiated once for each R4875G1.

The main configuration provides:

```text
ru_unit = 1
ru_unit = 2
ru_unit = 3
```

Each instance owns per-unit:

- CAN watchdog timestamp
- lifecycle state
- thermal state
- overtemperature lockout
- discovery flags
- discovery counters
- property buffer
- telemetry sensors
- static identification sensors
- maximum-current capability
- unit-specific discovery scripts
- unit-specific START control

Public IDs intentionally resolve to stable per-unit names.

Shared cross-unit policy does not belong in this package.

---

## `rectifier-can/`

Contains parameterized CAN receive fragments used by the shared CAN interface.

Every fragment receives at least:

```text
ru_unit
```

as a substitution.

### `property-start.yaml`

Handles:

```text
0x108${ru_unit}D27F
```

Starts and accumulates the multi-frame ASCII static-property response.

### `property-end.yaml`

Handles:

```text
0x108${ru_unit}D27E
```

Completes the property response, parses required keys and marks static-property discovery complete only when all required values have been decoded.

### `cyclic-telemetry.yaml`

Handles:

```text
0x108${ru_unit}407F
```

Decodes selector-based operational telemetry such as:

- AC power
- AC frequency
- AC current
- AC voltage
- DC power
- DC voltage
- DC current
- temperatures
- operating hours
- rectifier-reported current setpoint

### `fan-telemetry.yaml`

Handles:

```text
0x108${ru_unit}827E
```

Decodes internal rectifier-fan telemetry:

- minimum duty
- target duty
- fan RPM

### `address-data.yaml`

Handles:

```text
0x108${ru_unit}507E
```

Decodes shelf/slot address data used during discovery.

### `power-state.yaml`

Handles:

```text
0x100${ru_unit}117E
```

Publishes:

- rectifier ON/OFF/ERROR state
- alternate DC-current freshness telemetry

---

# Display Architecture

The V6 display implementation separates static LVGL layout from periodic runtime updates.

This separation is important because updating every widget continuously caused unnecessary LVGL load on the controller.

The current architecture is:

```text
display.yaml
│
├── display/hardware.yaml
├── display/theme.yaml
├── display/ui.yaml
│
├── persistent/global runtime
│   ├── display/header.yaml
│   ├── display/command-state.yaml
│   └── display/controller-battery.yaml
│
├── page-specific runtime
│   ├── display/dashboard.yaml
│   ├── display/rectifiers.yaml
│   ├── display/rectifier-detail.yaml
│   ├── display/battery.yaml
│   ├── display/cooling.yaml
│   ├── display/system.yaml
│   └── display/trends.yaml
│
└── static page layouts
    └── display/pages/*.yaml
```

Only the currently visible page receives normal page-specific runtime updates.

Persistent header state, command-transition state and controller-battery display updates continue independently.

---

## `display.yaml`

Display package aggregator.

It includes:

- physical display hardware
- theme and styles
- shared UI tree
- persistent display runtimes
- page-specific runtimes

It should contain package composition rather than page logic.

---

## `display/hardware.yaml`

Owns the Waveshare RGB display hardware.

Responsibilities include:

- 800 × 480 RGB panel configuration
- display timing
- framebuffer configuration
- LVGL display binding
- backlight control

Touchscreen hardware is owned by the controller-wide `hardware.yaml` because GT911 shares the main I2C bus and reset infrastructure with other controller hardware.

---

## `display/theme.yaml`

Owns reusable presentation definitions including:

- fonts
- card styles
- page styles
- header styles
- navigation styles
- common LVGL defaults

It should not own live telemetry or control-state logic.

---

## `display/ui.yaml`

Owns the persistent LVGL widget tree and shared UI state.

Responsibilities include:

- page aggregation
- persistent header layout
- bottom navigation
- shared dialogs
- shared UI globals
- fallback-edit dialog state
- active display-page tracking

Periodic telemetry refresh does not belong in this file.

---

# Persistent Display Runtime

## `display/header.yaml`

Updates the persistent header independently of the active page.

Typical header information includes:

- date/time
- firmware identity
- charger run state
- controller backup-battery indication

---

## `display/command-state.yaml`

Owns asynchronous START/STOP transition display state.

Pending command state remains active even if the user leaves the page where the command originated.

This prevents command-completion handling from depending on one visible page.

---

## `display/controller-battery.yaml`

Updates controller backup-battery presentation.

Battery values change slowly and therefore use an independent low-rate refresh rather than being tied to faster page runtimes.

---

# Page-Specific Display Runtime

## `display/dashboard.yaml`

Updates Dashboard telemetry and charger-wide control presentation.

Runtime executes only while the Dashboard page is visible.

---

## `display/rectifiers.yaml`

Updates the three-unit Rectifiers overview.

Runtime includes:

- lifecycle state
- power state
- AC/DC summary telemetry
- button state
- unit availability

---

## `display/rectifier-detail.yaml`

Updates the shared Rectifier Detail page.

One page is reused for all three units.

The currently selected unit is stored in:

```text
rectifier_detail_unit
```

Runtime selects the corresponding telemetry dynamically.

---

## `display/battery.yaml`

Updates the four individual solar-battery cards.

Runtime executes only while the Battery page is visible.

The runtime consumes the centralized battery telemetry and availability state from `battery-bank.yaml` and renders:

- per-battery measurements
- warning and fault state
- consolidated battery status
- explicit missing-data presentation

It does not own battery acquisition or charger-control behavior.

---

## `display/cooling.yaml`

Updates the Cooling page.

The current page focuses on:

- shared compartment temperature
- shared compartment humidity
- internal Huawei rectifier-fan telemetry

External chassis-fan control is owned by `cooling.yaml`.

---

## `display/system.yaml`

Updates controller diagnostics including:

- network information
- controller runtime information
- memory information
- CAN / rectifier status

Controller battery values are updated separately by `display/controller-battery.yaml`.

---

## `display/trends.yaml`

Owns the native LVGL chart runtime.

Five independent 120-sample ring buffers are recorded continuously by `rectifier-shared.yaml`.

The display runtime:

- selects the active trend
- calculates current/minimum/maximum values
- determines the dynamic Y-axis range
- populates the LVGL series
- renders unavailable samples as gaps

The native LVGL chart helper remains in:

```text
../trend_helpers.h
```

---

# Static Display Pages

The files under:

```text
display/pages/
```

define LVGL layout only.

They SHOULD NOT own periodic telemetry-refresh logic.

Current pages:

```text
dashboard.yaml
rectifiers.yaml
rectifier-detail.yaml
battery.yaml
cooling.yaml
system.yaml
trends.yaml
```

The main navigation exposes:

```text
Dashboard
Rectifiers
Battery
Cooling
System
Trends
```

Rectifier Detail is a hierarchical child view rather than an additional main navigation page.

---

# Data and Control Paths

## Telemetry Path

Normal per-unit telemetry follows:

```text
R4875G1
   │
   │ CAN
   ▼
rectifier-can/*.yaml
   │
   ▼
rectifier-unit.yaml sensors
   │
   ├── Home Assistant / MQTT / Web
   │
   └── display page runtimes
```

Shared aggregate values are calculated above the per-unit telemetry layer.

---

## Charger Control Path

User intent follows approximately:

```text
controls.yaml
     │
     ▼
rectifier-shared.yaml
     │
     ├── hardware capability limit
     ├── thermal limit
     └── lifecycle / CAN eligibility
     │
     ▼
per-unit CAN command
     │
     ▼
R4875G1
```

This separation prevents UI entities from bypassing charger safety policy.

---

## Discovery Path

```text
OFFLINE unit
    │
    │ valid reconnect telemetry
    ▼
DISCOVERING
    │
    ▼
serialized discovery queue
    │
    ├── static properties
    ├── maximum-current capability
    └── address data
    │
    ▼
reapply active setpoints
    │
    ▼
ONLINE
```

Discovery is serialized because multi-frame property traffic temporarily requires coordinated access to the shared CAN bus.

---

## Display Update Path

```text
sensor / control state
        │
        ▼
page-specific runtime
        │
        ▼
currently visible LVGL page
```

Persistent state uses separate runtimes:

```text
header
command transitions
controller battery
```

This architecture avoids continuously refreshing hidden pages.

---

# Documentation Ownership

The documentation hierarchy is:

```text
../README.md
    project overview, hardware, operation and safety

README.md
    package ownership and implementation architecture

../R4875G1_CONTROL_FLOWS.md
    detailed lifecycle and control-flow behavior

../rules/
    repository development rules
```

Implementation-local details SHOULD remain close to the corresponding YAML rather than being duplicated here.

When package ownership or architecture changes, this document should be updated as part of the same functional change or immediately afterwards.