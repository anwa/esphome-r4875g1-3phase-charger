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
│   ├── ui-rectifier-unit.yaml
│   ├── ui-battery-unit.yaml
│   ├── ui-contract.yaml
│   ├── battery-bank.yaml
│   ├── battery-monitoring.yaml
│   ├── battery-ui-backend.yaml
│   ├── battery-ui-unit-backend.yaml
│   ├── core.yaml
│   ├── local-diagnostics.yaml
│   ├── hardware.yaml
│   └── ui-model.yaml
│
├── controller/
│   ├── encoder-ui.yaml
│   ├── encoder.yaml
│   ├── environment.yaml
│   ├── hardware.yaml
│   ├── mqtt.yaml
│   ├── ui-backend.yaml
│   ├── ui-commands.yaml
│   └── ui-rectifier-backend.yaml
│
├── remote-hmi/
│   ├── connection-status.yaml
│   ├── ha-entity-map.yaml
│   ├── ha-backend.yaml
│   ├── rectifier-backend.yaml
│   └── ui-commands.yaml
│
├── controls.yaml
├── cooling.yaml
├── display.yaml
├── rectifier-shared.yaml
├── rectifier-unit.yaml
├── README.md
│
├── display/
│   ├── ui-state.yaml
│   ├── trend-state.yaml
│   ├── chart-support.yaml
│   ├── homeassistant-motion.yaml
│   ├── header-ui.yaml
│   ├── dashboard-ui.yaml
│   ├── dashboard-command-state.yaml
│   ├── rectifiers-ui.yaml
│   ├── battery-ui.yaml
│   ├── cooling-ui.yaml
│   ├── system-ui.yaml
│   ├── trends-ui.yaml
│   ├── fallback-dialog.yaml
│   ├── rectifier-power-dialogs.yaml
│   ├── shared-rectifiers.yaml
│   ├── shared-battery.yaml
│   ├── shared-cooling.yaml
│   ├── shared-system.yaml
│   ├── shared-trends.yaml
│   ├── shared-navigation.yaml
│   ├── hardware.yaml
│   ├── theme.yaml
│   ├── header.yaml
│   ├── command-state.yaml
│   ├── battery.yaml
│   ├── dashboard.yaml
│   ├── rectifiers.yaml
│   ├── rectifier-detail.yaml
│   ├── cooling.yaml
│   ├── system.yaml
│   ├── trends.yaml
│   ├── shared-hmi.yaml
│   ├── shared-dashboard.yaml
│   ├── local-battery-header.yaml
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

shared/local-diagnostics.yaml
    target-local network, ESP32 and runtime diagnostics shared by both V6 targets

shared/ui-model.yaml
    target-neutral aggregate state contract consumed by the HMI

shared/ui-contract.yaml
    shared HMI command ranges used by both V6 targets

shared/battery-bank.yaml
    shared Home Assistant solar-battery telemetry import and availability state

shared/battery-monitoring.yaml
    composes the shared battery source and aggregate/per-unit UI-model backends

shared/battery-ui-backend.yaml
    publishes validated aggregate battery-bank monitoring state into the shared UI model

shared/battery-ui-unit-backend.yaml
    publishes one validated battery unit into the shared per-unit UI model

shared/ui-battery-unit.yaml
    parameterized target-neutral UI state for one solar-battery unit

shared/ui-rectifier-unit.yaml
    parameterized target-neutral UI state for one rectifier

controller/hardware.yaml
    Charger Controller buses and charger-side peripherals

controller/environment.yaml
    Charger Controller rectifier-compartment environment sensing

controller/mqtt.yaml
    Charger Controller MQTT transport

controller/ui-backend.yaml
    publishes authoritative local charger state into the shared UI model

controller/ui-commands.yaml
    executes shared UI command intents through local Charger Controller entities

controller/encoder.yaml
    owns the network-independent local backup encoder state machine and control requests

controller/encoder-ui.yaml
    provides Controller-only LVGL feedback for backup encoder interaction

controller/ui-rectifier-backend.yaml
    publishes one local rectifier into the shared per-unit UI model

remote-hmi/connection-status.yaml
    exposes persistent Remote HMI Home Assistant / charger-data connectivity in the shared header

remote-hmi/ha-entity-map.yaml
    derives paired Charger Controller Home Assistant entities from one configurable prefix

remote-hmi/ha-backend.yaml
    imports authoritative Charger Controller state through Home Assistant

remote-hmi/ui-commands.yaml
    transports shared UI command intents to the Charger Controller through Home Assistant

remote-hmi/rectifier-backend.yaml
    imports one authoritative rectifier state through Home Assistant

controls.yaml
    charger-wide user setpoints and controls

cooling.yaml
    external chassis cooling

display.yaml
    display package aggregation

rectifier-shared.yaml
    cross-unit lifecycle, safety and CAN scheduling

rectifier-unit.yaml
    parameterized per-unit state and telemetry

display/*.yaml
    persistent and page-specific display runtime

display/ui-state.yaml
    shared LVGL presentation, navigation and command-pending state

display/trend-state.yaml
    shared local 60-minute HMI trend history sampled from the target-neutral UI model

display/chart-support.yaml
    shared LVGL chart build support used by both V6 HMI targets

display/homeassistant-motion.yaml
    optional target-specific Home Assistant motion source for shared display activity

display/header-ui.yaml
    shared persistent header layout

display/dashboard-ui.yaml
    shared Dashboard page and Dashboard-specific dialogs

display/dashboard-command-state.yaml
    shared charger-wide START/STOP presentation state

display/command-state.yaml
    shared per-rectifier START/STOP pending-state resolution

display/shared-hmi.yaml
    shared display infrastructure, chart support, persistent header, trend history and presentation state

display/shared-dashboard.yaml
    shared Dashboard presentation and runtime consumed by both V6 firmware targets

display/shared-rectifiers.yaml
    shared Rectifiers composition consumed by both V6 firmware targets

display/shared-battery.yaml
    shared Battery presentation and runtime consumed by both V6 firmware targets

display/shared-cooling.yaml
    shared Cooling presentation and runtime consumed by both V6 firmware targets

display/shared-system.yaml
    shared System presentation and runtime consumed by both V6 firmware targets

display/shared-trends.yaml
    shared Trends presentation and chart runtime consumed by both V6 firmware targets

display/shared-navigation.yaml
    shared Dashboard, Rectifiers, Battery, System, Cooling and Trends bottom navigation

display/rectifiers-ui.yaml
    shared Rectifiers Overview and Detail presentation

display/battery-ui.yaml
    shared Battery page presentation

display/cooling-ui.yaml
    shared Cooling page presentation

display/trends-ui.yaml
    shared Trends page presentation

display/cooling.yaml
    shared Cooling page runtime

display/system-ui.yaml
    shared System page presentation

display/system.yaml
    shared local-target diagnostics and rectifier-status page runtime

display/trends.yaml
    shared native LVGL Trends chart runtime

display/fallback-dialog.yaml
    shared fallback-setpoint dialog

display/rectifier-power-dialogs.yaml
    parameterized shared per-unit START/STOP dialogs

display/local-battery-header.yaml
    shared local display-controller backup-battery header runtime

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
- ESPHome debug-component support

Target-specific command and telemetry transports do not belong in this package.

---

## `shared/local-diagnostics.yaml`

Owns target-local diagnostic entities that are common to the Charger Controller and Remote HMI.

Responsibilities include:

- heap and PSRAM diagnostics
- maximum free heap block
- ESPHome loop time
- CPU frequency and temperature
- device uptime
- Wi-Fi RSSI and IP address
- ESPHome version
- device information and reset reason

The diagnostics describe the ESP32 running the current firmware target. They do not represent charger operational state and do not participate in charger control or safety.

---

## `shared/hardware.yaml`

Owns physical Waveshare ESP32-S3-Touch-LCD-7 hardware that is independent of the charger-side backend.

Responsibilities include:

- onboard I2C bus
- GT911 touchscreen
- CH422G onboard I/O expander
- local display-controller backup-battery ADC and SOC estimate

This package contains board hardware that can be reused by multiple firmware targets without requiring charger-side peripherals. Local backup-battery entity names use the target's `diagnostics_device_label`, while the internal runtime IDs remain target-neutral.

---

## `shared/ui-model.yaml`

Owns the target-neutral runtime state consumed by shared HMI code.

The model isolates LVGL presentation from the source of charger data. Charger Controller and Remote HMI backends publish into the same model IDs so shared display code does not need target-specific telemetry paths.

The current model includes Dashboard AC/DC aggregate telemetry, active and fallback charger setpoints, rectifier availability/run state, per-rectifier overview and detail telemetry, highest output temperature, conversion efficiency and aggregate solar-battery-bank monitoring state. Parameterized per-battery monitoring state is defined in `shared/ui-battery-unit.yaml`.

---

## `controller/hardware.yaml`

Owns physical hardware that exists only on the Charger Controller.

Responsibilities include:

- dedicated charger-side external I2C bus
- MCP23017 external I/O expander for external fan power and tachometer signals
- direct-GPIO backup rotary-encoder inputs
- USB/CAN routing selection
- ESP32-S3 TWAI / onboard CAN interface

The MCP23017 INTA and INTB outputs are intentionally unconnected. The direct encoder uses GPIO11, GPIO12 and GPIO13, which makes the Waveshare TF-card interface unavailable on the Charger Controller.

---

## `controller/environment.yaml`

Owns the Charger Controller rear-compartment environmental sensor.

Responsibilities include:

- BME280 access on the dedicated external I2C bus
- rectifier-compartment temperature and humidity
- physical station pressure
- standard-atmosphere sea-level pressure correction for the configured 316 m installation altitude

The established compartment temperature and humidity IDs remain unchanged so cooling control and the Controller UI backend continue to consume the same local interface.

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

## `controller/ui-commands.yaml`

Implements the shared HMI command interface for the Charger Controller target.

The command scripts translate target-neutral Dashboard, fallback-setpoint and per-rectifier command intent into the existing local ESPHome controls. Charger safety, validation and CAN execution remain owned by the existing Controller entities and scripts.

---

## `controller/encoder.yaml`

Owns the Charger Controller backup rotary-encoder state machine.

The encoder provides local DC-voltage and nominal DC sum-power editing plus deliberate long-press charger START/STOP requests. It reuses the existing `ui_command_*` command paths rather than duplicating charger safety or CAN logic.

The control state is independent from normal LVGL navigation and from Home Assistant, MQTT and Internet connectivity.

---

## `controller/encoder-ui.yaml`

Owns the Controller-only LVGL feedback overlay for backup encoder interaction.

The overlay blocks touchscreen controls while an encoder setpoint edit is active and shows short status feedback after saved setpoints or charger power requests. It is presentation-only; charger-control authority remains outside LVGL.

---

## `remote-hmi/connection-status.yaml`

Provides persistent Remote-HMI-specific connectivity presentation in the target-specific status area of the shared persistent header.

The status clearly indicates whether authoritative Charger Controller data is currently available through Home Assistant across the shared HMI pages. It does not duplicate charger state or safety logic.

---

## `remote-hmi/ha-entity-map.yaml`

Owns the Home Assistant entity mapping for the Charger Controller paired with a Remote HMI.

The Remote HMI root defines one installation-specific `ha_charger_entity_prefix`. The entity map derives the Dashboard telemetry, setpoint, charger-wide command, per-rectifier state and per-rectifier command entity IDs from that prefix.

This keeps Home Assistant entity naming out of the state and command backends and allows another Charger Controller to be paired by changing one configuration value.

The same prefix is used for all three rectifier backends, so per-unit Home Assistant mappings do not require separate installation-specific configuration.

The configured prefix must match the actual Home Assistant entity IDs. Home Assistant may preserve existing entity IDs after an ESPHome device is renamed, so the prefix is not inferred dynamically from the current device name.

---

## `remote-hmi/ha-backend.yaml`

Owns the Remote HMI Home Assistant transport.

It imports authoritative Charger Controller entities from Home Assistant and publishes them into the shared UI model. Shared LVGL code therefore consumes the same `ui_model_*` entities on both firmware targets.

The backend supplies Charger-side Dashboard telemetry, active and fallback setpoint state required by the shared UI model. Charger command transport remains separate.

Loss of the Home Assistant state-subscription connection invalidates Remote HMI charger state so stale values cannot appear as live telemetry.

Home Assistant entity IDs are supplied by `remote-hmi/ha-entity-map.yaml` rather than being embedded in the backend.

---

## `remote-hmi/ui-commands.yaml`

Implements the shared HMI command interface for the Remote HMI target.

The backend sends charger-wide, fallback-setpoint and per-rectifier command requests through Home Assistant to the Charger Controller entities. It does not duplicate safety logic and does not treat a request as confirmed charger state.

The shared UI model remains authoritative for displayed command results after Home Assistant reports the resulting Charger Controller state.

Command target entity IDs are supplied by `remote-hmi/ha-entity-map.yaml`.

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
    ├── BME280 @ 0x76
    └── EMC2101 @ 0x4C
```

The onboard I2C bus is configured in `shared/hardware.yaml`. The charger-side external I2C bus and MCP23017 are configured in `controller/hardware.yaml`. The BME280 environment sensor is configured in `controller/environment.yaml`, while the EMC2101 fan controller is configured in `cooling.yaml`.

### Charger Controller Local I/O Allocation

The backup rotary encoder is connected directly to the ESP32-S3:

```text
GPIO11 -> Encoder S1 / A
GPIO12 -> Encoder S2 / B
GPIO13 -> Encoder KEY
```

The MCP23017 is reserved for external cooling-fan I/O:

```text
GPA0 -> external cooling-fan supply enable
GPA1 -> Cooling Fan 1 tachometer
GPA2 -> Cooling Fan 2 tachometer
INTA -> not connected
INTB -> not connected
```

The encoder hardware is defined in `controller/hardware.yaml`, while its local control state machine is owned by `controller/encoder.yaml`.

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
MCP23017 GPA0 -> common fan-supply enable
MCP23017 GPA1 -> Cooling Fan 1 tachometer
MCP23017 GPA2 -> Cooling Fan 2 tachometer

EMC2101 PWM   -> common four-pin fan PWM
EMC2101 TACH  -> Cooling Fan 3 tachometer

BME280        -> rear-compartment temperature, humidity and pressure
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

Cooling Fan 3 ventilates the rear rectifier compartment monitored by the BME280.

Automatic cooling fails safe to enabled fan power and maximum PWM if the compartment temperature becomes unavailable.

---

## `shared/battery-bank.yaml`

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

## `shared/battery-monitoring.yaml`

Composes the Home Assistant battery source, aggregate UI backend and four parameterized per-unit UI-model/backend pairs used by both V6 targets.

The aggregate battery-bank model remains part of `shared/ui-model.yaml`; per-unit Battery-page state is provided by `shared/ui-battery-unit.yaml`.

---

## `shared/ui-battery-unit.yaml`

Defines target-neutral monitoring state for one solar-battery unit.

Each instance provides per-unit data availability, warning/fault state, voltage, current, power, state of charge, temperature and cell drift.

---

## `shared/battery-ui-backend.yaml`

Publishes validated aggregate battery-bank monitoring state into the shared UI model and exposes the common Home Assistant battery-source connectivity state.

Unavailable aggregate battery data is invalidated before it reaches shared LVGL code so stale monitoring values cannot appear as live state.

---

## `shared/battery-ui-unit-backend.yaml`

Publishes one validated battery unit into the parameterized per-unit UI model.

Both V6 targets use the same Home Assistant battery source package, so this backend is shared rather than target-specific. Raw warning and fault text states are validated by `shared/battery-bank.yaml` and normalized to boolean UI-model state here.

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

The V6 display implementation uses one shared presentation architecture for the Charger Controller and Remote HMI. Static LVGL layout, page runtime, trend history and bottom navigation are shared; target-specific telemetry acquisition and command transport remain behind the shared UI-model and `ui_command_*` boundaries.

The Charger Controller composes the shared display stack through `display.yaml`. The Remote HMI root composes the same shared packages directly.

The current architecture is:

```text
display/shared-hmi.yaml
    shared display hardware, theme, chart support, UI state,
    local trend history and persistent header

display/shared-dashboard.yaml
display/shared-rectifiers.yaml
display/shared-battery.yaml
display/shared-cooling.yaml
display/shared-system.yaml
display/shared-trends.yaml
    page-specific shared presentation and runtime

display/shared-navigation.yaml
    shared six-page bottom navigation
```

Only the currently visible page receives normal page-specific display refreshes. Persistent header state, local backup-battery presentation, command-transition state and local trend sampling continue independently.

---

## `display.yaml`

Charger Controller display-package aggregator.

It composes the same shared HMI infrastructure, six shared main pages and shared bottom navigation used by the Remote HMI. The Remote HMI root composes those shared packages directly because it also owns target-specific Home Assistant backends and connectivity presentation.

It should contain package composition rather than page logic.

---

## `display/hardware.yaml`

Owns the Waveshare RGB display, backlight and LVGL hardware integration shared by both V6 targets.

Responsibilities include:

- 800 × 480 RGB panel configuration
- framebuffer configuration
- LVGL display binding
- shared touchscreen binding
- backlight control
- boot-time display/LVGL ordering behind network recovery services

The physical GT911 touchscreen is owned by `shared/hardware.yaml`; `display/hardware.yaml` binds that shared touchscreen to LVGL.

The RGB display and LVGL use explicit setup priorities below Wi-Fi and the API/OTA services. This allows networking to reserve scarce internal and DMA-capable memory before the display stack starts while preserving the required display-before-LVGL dependency.

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

## `display/shared-hmi.yaml`

Owns common display infrastructure and persistent presentation state used by all shared pages.

Responsibilities include:

- RGB display/LVGL integration
- shared theme
- native LVGL chart support
- active-page and presentation state
- local sixty-minute trend-history state
- persistent shared header
- local display-controller backup-battery presentation

Page-specific layout and runtime remain in the corresponding `shared-*.yaml` composition packages.

---

## `display/shared-navigation.yaml`

Owns the six main navigation buttons shared by both V6 targets:

```text
Dashboard
Rectifiers
Battery
System
Cooling
Trends
```

Rectifier Detail remains a hierarchical child page and is not a seventh main-navigation item.

---

# Persistent Display Runtime

## `display/header.yaml`

Updates the persistent shared header independently of the active page.

Typical header information includes:

- date/time
- firmware identity
- charger run state
- local display-controller backup-battery indication

The Remote HMI adds its Home Assistant connectivity state through the target-specific `remote-hmi/connection-status.yaml` fragment.

---

## `display/command-state.yaml`

Owns asynchronous per-rectifier START/STOP transition display state.

Pending command state remains active even if the user leaves the page where the command originated.

This prevents command-completion handling from depending on one visible page.

---

## `display/local-battery-header.yaml`

Updates the local Waveshare display-controller backup-battery presentation shared by both targets.

Battery values change slowly and therefore use an independent low-rate refresh rather than being tied to faster page runtimes.

---

## `display/shared-dashboard.yaml`

Composes Dashboard-specific presentation and runtime consumed identically by both firmware targets.

Shared display infrastructure and persistent state are owned separately by `display/shared-hmi.yaml`. Target-specific state acquisition and command transport remain outside the Dashboard package behind the shared UI-model and `ui_command_*` interfaces.

---

## `display/shared-trends.yaml`

Composes the shared Trends page presentation and native chart runtime for both firmware targets.

Trend history and native chart build support remain owned by `display/shared-hmi.yaml` through `trend-state.yaml` and `chart-support.yaml`.

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

Updates target-local diagnostics and shared rectifier status including:

- network information
- target runtime information
- memory information
- rectifier connectivity state

Local display-controller battery values are updated separately by `display/local-battery-header.yaml`.

---

## `display/trends.yaml`

Owns the shared native LVGL chart runtime.

Five independent 360-sample ring buffers are maintained locally on each V6 target by `display/trend-state.yaml`. They are sampled every ten seconds from the target-neutral shared UI model, providing sixty minutes of local history without Home Assistant history queries.

The display runtime:

- selects the active trend
- reads live values from the shared UI model
- combines DC current and DC voltage in one dual-axis chart
- calculates current/minimum/maximum values independently for both DC I/V series
- determines independent dynamic primary and secondary Y-axis ranges
- populates one or two LVGL series depending on the active trend
- renders unavailable samples as gaps

Native LVGL chart support is enabled by `display/chart-support.yaml`; the helper declarations remain in:

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
System
Cooling
Trends
```

Rectifier Detail is a hierarchical child view rather than an additional main navigation page.

---

# Data and Control Paths

## Telemetry Path

The Charger Controller receives authoritative rectifier telemetry locally and publishes the HMI-facing state through the Controller UI backend:

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
   ▼
controller/ui-backend.yaml
controller/ui-rectifier-backend.yaml
   │
   ▼
shared UI model
   │
   ▼
shared page runtimes
   │
   ▼
currently visible LVGL page
```

The Remote HMI receives the same authoritative charger state through Home Assistant and translates it into the same shared UI model:

```text
Charger Controller entities
   │
   │ Home Assistant
   ▼
remote-hmi/ha-backend.yaml
remote-hmi/rectifier-backend.yaml
   │
   ▼
shared UI model
   │
   ▼
shared page runtimes
   │
   ▼
currently visible LVGL page
```

Shared LVGL code therefore does not depend directly on CAN or raw Home Assistant transport entities.

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
shared UI model
      │
      ▼
page-specific runtime
      │
      ▼
currently visible LVGL page
```

Persistent or target-local presentation uses separate runtimes:

```text
shared header
command transitions
local display-controller battery
local trend sampling
Remote HMI connection status
```

This architecture avoids continuously refreshing hidden pages while keeping persistent state independent of page visibility.

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