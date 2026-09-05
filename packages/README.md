# Firmware Package Architecture

This directory contains the modular ESPHome implementation of the three-phase Huawei R4875G1 charger controller.

The root configuration:

```text
../r4875g1-3phase-charger.yaml
```

assembles these packages into the complete firmware.

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
├── core.yaml
├── hardware.yaml
├── controls.yaml
├── cooling.yaml
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
core.yaml
    controller-wide ESPHome infrastructure

hardware.yaml
    physical controller buses and peripherals

controls.yaml
    charger-wide user setpoints and controls

cooling.yaml
    external chassis cooling

rectifier-shared.yaml
    cross-unit lifecycle, safety and CAN scheduling

rectifier-unit.yaml
    parameterized per-unit state and telemetry

rectifier-can/*.yaml
    parameterized CAN receive fragments

display.yaml
    display package aggregation

display/pages/*.yaml
    static LVGL page layouts

display/*.yaml
    persistent and page-specific display runtime
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

## `core.yaml`

Owns controller-wide ESPHome infrastructure.

Responsibilities include:

- ESP32-S3 platform and framework configuration
- Flash and PSRAM configuration
- Wi-Fi
- ESPHome native API
- MQTT
- web server
- OTA
- time synchronization
- general controller services

Hardware-specific charger logic does not belong in this package.

---

## `hardware.yaml`

Owns the physical V5 controller hardware that is shared across multiple functional packages.

The current controller target is the Waveshare ESP32-S3-Touch-LCD-7.

Responsibilities include:

- shared I2C bus
- TCA9548A external I2C multiplexer
- MCP23017 external I/O expander
- GT911 touchscreen
- CH422G onboard I/O expander
- USB/CAN routing selection
- ESP32-S3 TWAI / onboard CAN interface
- backup rotary-encoder inputs
- controller backup-battery ADC and SOC estimate

### Shared I2C Topology

```text
ESP32-S3
│
├── GPIO8 -> SDA
├── GPIO9 -> SCL
│
└── TCA9548A @ 0x70
    ├── CH0 -> MCP23017 @ 0x20
    ├── CH1 -> AHT10 @ 0x38
    └── CH2 -> EMC2101 @ 0x4C
```

The EMC2101 component itself is configured in `cooling.yaml`, but its I2C bus is provided by `hardware.yaml`.

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
No charger-control or navigation actions are assigned to them in the current V5 firmware.

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
- common external fan PWM
- common fan-supply enable
- three independent RPM measurements
- automatic temperature-based cooling
- manual fan-power and PWM override

Cooling Fan 3 ventilates the rear rectifier compartment monitored by the AHT10.

Automatic cooling fails safe to enabled fan power and maximum PWM if the compartment temperature becomes unavailable.

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

The V5 display implementation separates static LVGL layout from periodic runtime updates.

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
│   └── display/battery.yaml
│
├── page-specific runtime
│   ├── display/dashboard.yaml
│   ├── display/rectifiers.yaml
│   ├── display/rectifier-detail.yaml
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

## `display/battery.yaml`

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

Controller battery values are updated separately by `display/battery.yaml`.

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
cooling.yaml
system.yaml
trends.yaml
```

The main navigation exposes:

```text
Dashboard
Rectifiers
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