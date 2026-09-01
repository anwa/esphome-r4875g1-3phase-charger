> **v5 migration:** `main` targets the Waveshare ESP32-S3-Touch-LCD-7.
> The stable v4 package architecture remains available on `v4-maintenance`
> and as tag `v4.4.0`.
>
> Legacy v4 hardware definitions are temporarily retained where required by
> packages that have not yet been migrated.

# Firmware package architecture

This directory contains the modular ESPHome implementation of the three-phase Huawei R4875G1 charger controller.

The root configuration:

```text
../r4875g1-3phase-charger.yaml
```

assembles the packages in this directory into the complete firmware.

Current stable firmware on `main`:

```text
v4.3.0
```

Feature branches may contain newer development versions.

For the complete project documentation, hardware description, CAN protocol information, commissioning and troubleshooting, see:

```text
../README.md
```

For detailed runtime/state-machine behavior, see:

```text
../R4875G1_CONTROL_FLOWS.md
```

---

# Package structure

```text
packages/
├── version.yaml
├── core.yaml
├── hardware.yaml
├── display.yaml
├── cooling.yaml
├── controls.yaml
├── rectifier-shared.yaml
├── rectifier-unit.yaml
├── README.md
│
├── display/
│   ├── hardware.yaml
│   ├── theme.yaml
│   ├── ui.yaml
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

# Package ownership

## `version.yaml`

Single source of truth for the firmware version.

Example:

```yaml
substitutions:
  firmware_version: "4.3.2"
```

The value is consumed by:

* `esphome.project.version`
* the TFT
* deployment tooling
* project documentation

Normal program commits increment PATCH exactly once.

Pure documentation or repository-cleanup commits do not require a firmware-version change.

Intentional releases may advance MINOR or MAJOR and reset PATCH.

---

## `core.yaml`

Owns controller-wide ESPHome infrastructure including:

* ESP32-S3 platform/framework configuration
* flash configuration
* PSRAM configuration
* Wi-Fi
* API
* MQTT
* web server
* OTA
* SNTP/time services
* general controller services

Hardware-specific charger logic should not be placed here.

---

## `hardware.yaml`

Owns shared hardware buses used by multiple packages.

Current shared buses include:

```text
I2C
SPI
```

Current I2C allocation:

```text
SDA GPIO8
SCL GPIO9
```

The AHT10 uses the shared I2C bus.

---

# Display architecture

The display stack is intentionally separated into transport, shared presentation and page-specific content.

```text
display.yaml
    ↓
display/hardware.yaml
display/theme.yaml
display/ui.yaml
    ↓
display/pages/dashboard.yaml
display/pages/rectifiers.yaml
display/pages/rectifier-detail.yaml
display/pages/cooling.yaml
display/pages/system.yaml
display/pages/trends.yaml
```

---

## `display.yaml`

Display package aggregator.

It defines display-related substitutions and includes the actual display subpackages.

---

## `display/hardware.yaml`

Owns the physical ILI9488 interface:

* SPI transport
* display dimensions
* panel orientation
* display transform
* TFT backlight

Current display:

```text
ILI9488
480 × 320
RGB565
landscape
```

---

## `display/theme.yaml`

Owns:

* LVGL configuration
* framebuffer configuration
* fonts
* reusable styles
* common visual defaults

The controller has no touchscreen.

Therefore scrolling is not part of the UI concept.

Generic LVGL containers have scrolling and scrollbar rendering disabled.

Page/header/card containers additionally define the same policy explicitly:

```yaml
scrollable: false
scrollbar_mode: "OFF"
```

This avoids LVGL scrollbar inheritance differences and prevents unusable horizontal or vertical scrollbars.

---

## `display/ui.yaml`

Aggregates the five LVGL main pages plus the hierarchical Rectifier detail page.

Page order:

```text
0 Dashboard
1 Rectifiers
2 Cooling
3 System
4 Trends
```

Page wrapping is enabled:

```text
Dashboard
  ↓
Rectifiers
  ↓
Cooling
  ↓
System
  ↓
Trends
  ↓
Dashboard
```

The encoder state machine uses the same page numbering through `encoder_page`.

---

# Display pages

## `display/pages/dashboard.yaml`

Main charger operating page.

Displays:

* date/time
* firmware version
* aggregate charger ON/OFF state
* combined AC power
* combined DC power
* AC voltage/current summary
* DC voltage/current summary
* available rectifier count
* highest output temperature
* conversion efficiency
* DC Voltage setpoint
* nominal three-unit DC Power setpoint
* applied current per unit

Run-state colors:

```text
OFF      red
1/3 ON   red
2/3 ON   red
3/3 ON   green
```

Partial operation is intentionally treated as an attention state.

Editable encoder parameters:

```text
0 DC Voltage
1 DC Power
```

---

## `display/pages/rectifiers.yaml`

Per-unit diagnostic page.

Contains one card for each rectifier:

```text
L1
L2
L3
```

Each card displays:

* power state
* CAN communication state
* lifecycle state
* DC voltage
* DC current
* DC power
* input temperature
* output temperature
* internal rectifier fan RPM
* detected maximum-current capability

Status colors:

```text
CAN fault      red
DISCOVERING    amber
ONLINE         green
OFFLINE        muted
```

Unreachable units use placeholders instead of stale live telemetry.

The overview is read-only with respect to charger parameters, but it
participates in hierarchical navigation.

Encoder selection values:

```text
0 = L1 / Unit 1
1 = L2 / Unit 2
2 = L3 / Unit 3
```

Rotation changes the selected unit and the currently selected card is marked
with `>`.

A short press opens `rectifier-detail.yaml` for the selected unit.

---

## `display/pages/rectifier-detail.yaml`

Shared hierarchical detail view for all three R4875G1 units.

The selected unit is stored in:

```text
rectifier_detail_unit
```

Values:

```text
0 = no detail page / Rectifiers overview
1 = L1 / Unit 1
2 = L2 / Unit 2
3 = L3 / Unit 3
```

One shared LVGL page is used instead of maintaining three nearly identical
page definitions.

The LVGL page uses:

```yaml
skip: true
```

so it is excluded from normal `lvgl.page.next` main-page navigation.

The detail page displays per-unit:

* Power State,
* CAN communication,
* lifecycle,
* AC input voltage,
* AC input current,
* AC input power,
* AC frequency,
* DC output voltage,
* DC output current,
* DC output power,
* rectifier-reported active maximum-current setpoint,
* input temperature,
* output temperature,
* internal fan RPM,
* internal fan target duty,
* internal fan minimum duty,
* maximum-current capability,
* operating hours.

The detail view contains no editable parameters.

Encoder behavior:

```text
Rotate        no action
Short press   no action
Double press  return to Rectifiers overview
Long press    global rectifier ON/OFF
```

Returning to the Rectifiers overview restores the L1/L2/L3 selection to the
unit whose detail page was just closed.

Live telemetry is validated before formatting. If CAN communication is
unavailable or one of the values required by an information block is `NAN`,
that block displays placeholders instead of stale or `nan` text.

---

## `display/pages/cooling.yaml`

External compartment-cooling page.

Displays:

* AHT10 compartment temperature
* AHT10 relative humidity
* automatic cooling state
* external fan power state
* PWM command
* automatic cooling stage
* Fan 1 RPM
* Fan 2 RPM
* Fan 3 RPM

Editable encoder parameters:

```text
0 Automatic
1 Fan Power
2 PWM
```

When automatic cooling is enabled:

```text
Automatic   selectable
Fan Power   disabled / muted
PWM         disabled / muted
```

When automatic cooling is disabled, all three parameters are selectable.

---

## `display/pages/system.yaml`

Controller diagnostic page.

Displays:

* firmware
* IP address
* Wi-Fi RSSI
* uptime
* CPU temperature
* free internal heap
* free PSRAM
* L1/L2/L3 CAN status

This page is read-only.

There are no selectable encoder parameters.

---

## `display/pages/trends.yaml`

Owns the local ten-minute trend display.

Five telemetry sources are recorded continuously:

```text
0 Combined DC Power
1 Combined DC Current
2 Average DC Voltage
3 Highest Rectifier Output Temperature
4 Rectifier Compartment Temperature
```

Sampling:

```text
5 seconds
120 samples
10 minutes
```

Each telemetry source has its own ring buffer, so changing the selected trend
does not reset or restart its history.

The page displays:

```text
selected trend
line chart
Current
Min
Max
```

Min and Max are calculated from the valid samples currently retained in the
selected 120-point ring buffer.

`NAN` values are preserved and displayed as chart gaps.

The current chart implementation directly uses native LVGL because the stable
ESPHome release does not yet expose the chart widget through its LVGL YAML
integration.

`LV_USE_CHART=1` is enabled by the root configuration and `trend_helpers.h`
provides the local LVGL include support.

This implementation is intended to be replaced by native ESPHome chart support
when it becomes available in a stable release.

---

# Encoder SELECT / EDIT architecture

The local encoder uses one page-aware state machine instead of page-specific button behavior.

Runtime state is stored in `rectifier-shared.yaml`.

Current globals:

```text
encoder_page
encoder_selection
encoder_edit_mode
encoder_edit_value
rectifier_detail_unit
trend_selection
trend_buffer_dc_power
trend_buffer_dc_current
trend_buffer_dc_voltage
trend_buffer_output_temp
trend_buffer_compartment_temp
trend_write_index
trend_sample_count
```

---

## `encoder_page`

Current LVGL page:

```text
0 Dashboard
1 Rectifiers
2 Cooling
3 System
4 Trends
```

A successful page change resets:

```text
encoder_selection = 0
```

---

## `rectifier_detail_unit`

Tracks hierarchical navigation below the Rectifiers main page.

```text
0 = Rectifiers overview
1 = Unit 1 / L1 detail
2 = Unit 2 / L2 detail
3 = Unit 3 / L3 detail
```

This state is deliberately separate from `encoder_page`.

While a detail view is open:

```text
encoder_page = 1
```

still identifies the logical main section as Rectifiers.

This allows the detail page to behave as a true child view rather than as
another main-menu page.

---

## `encoder_selection`

Identifies the selected parameter on the current page.

The meaning is page-specific.

Dashboard:

```text
0 Voltage
1 Power
```

Cooling:

```text
0 Automatic
1 Fan Power
2 PWM
```

Selection meaning is page-specific.

Rectifiers:

```text
0 L1 / Unit 1
1 L2 / Unit 2
2 L3 / Unit 3
````

System has no selectable parameters.

Trends uses `trend_selection` rather than `encoder_selection`:

```text
0 DC Power
1 DC Current
2 DC Voltage
3 Output Temperature
4 Compartment Temperature
```

---

## `encoder_edit_mode`

Boolean UI state:

```text
false = SELECT
true  = EDIT
```

The state is not restored across controller reboot.

The UI therefore always starts in a known SELECT state.

---

## `encoder_edit_value`

Temporary floating-point edit buffer.

When EDIT begins, the real value is copied into this buffer.

Encoder rotation changes only the buffer.

The actual ESPHome entity is not changed until the user confirms with a short press.

This prevents intermediate encoder steps from immediately transmitting changing charger setpoints.

---

# SELECT mode

Controls:

```text
Rotate        select parameter
Short press   enter EDIT
Double press  next page
Long press    global rectifier ON/OFF
```

The currently selected parameter is indicated by:

```text
>
```

Example:

```text
> Voltage  53.0 V
  Power     3.00 kW
```

On read-only pages, rotation and short press intentionally do nothing.

Double-click page navigation and long-press START/STOP remain available.

---

# EDIT mode

Controls:

```text
Rotate        modify temporary value
Short press   commit value and return to SELECT
Double press  disabled
Long press    disabled
```

The active parameter uses inverted presentation:

```text
dark background
white text
```

The normal `>` SELECT marker is removed.

The footer changes to:

```text
EDIT: Turn adjust | Press save
```

This provides both behavioral and visual separation between SELECT and EDIT.

---

# Editable parameter behavior

## Dashboard Voltage

```text
Range 49.0–58.0 V
Step  0.1 V
```

During EDIT, only `encoder_edit_value` changes.

On confirmation:

1. the new voltage is written to `set_dc_voltage_limit`;
2. the nominal total-power target is reapplied;
3. corresponding per-unit current is recalculated.

---

## Dashboard Power

```text
Range 0.25–12.0 kW
Step  0.25 kW
```

During EDIT, only the temporary buffer changes.

The actual power target changes only after confirmation.

---

## Cooling Automatic

Boolean:

```text
ON
OFF
```

Either encoder direction toggles the temporary Boolean value while editing.

After confirmation:

* ON enables automatic temperature control;
* OFF enables manual Fan Power/PWM selection.

---

## Cooling Fan Power

Boolean:

```text
ON
OFF
```

Selectable only when automatic cooling is OFF.

The actual GPIO power switch is changed only after confirmation.

---

## Cooling PWM

```text
Range 0–100 %
Step  1 %
```

Selectable only when automatic cooling is OFF.

The actual PWM number/output is updated only after confirmation.

---

# `cooling.yaml`

Owns the external/chassis cooling system.

This is separate from the internal R4875G1 fan CAN telemetry/control.

External hardware:

```text
common fan power enable
shared 25 kHz PWM
Fan 1 tachometer
Fan 2 tachometer
Fan 3 tachometer
AHT10 compartment sensor
```

Three-pin fans use:

```text
power
tachometer
```

Four-pin fans use:

```text
power
PWM
tachometer
```

---

# Automatic cooling

`Cooling Fan Automatic` defaults to enabled.

Control interval:

```text
5 seconds
```

Temperature curve:

| Temperature  |   Command |
| ------------ | --------: |
| `<30 °C`     | OFF / 0 % |
| `30–34.9 °C` |      35 % |
| `35–39.9 °C` |      45 % |
| `40–44.9 °C` |      60 % |
| `45–49.9 °C` |      80 % |
| `>=50 °C`    |     100 % |

Downward hysteresis:

```text
48 °C
43 °C
38 °C
33 °C
28 °C
```

A rising temperature immediately selects the required higher stage.

If compartment temperature is invalid:

```text
Fan Power ON
PWM 100 %
```

This is the intentional cooling fail-safe.

The AHT10 automatic OFF-below-30 °C path has been observed on hardware.

Full external fan PWM/RPM testing remains pending installation of the fans.

---

# `controls.yaml`

Owns charger-wide setpoints and controls.

Responsibilities include:

* requested DC voltage
* requested DC current
* nominal three-unit DC power
* fallback settings
* shared/broadcast control entities

The requested current remains conceptually separate from:

```text
effective hardware limit
thermal limit
applied current
```

---

# `rectifier-unit.yaml`

Parameterized implementation of one R4875G1.

The root configuration includes this package three times for:

```text
Unit 1
Unit 2
Unit 3
```

Per-unit public IDs and Home Assistant entity names should remain stable unless a change explicitly requires otherwise.

The package owns per-unit:

* telemetry
* discovery state
* static properties
* capability
* power state
* thermal state
* lifecycle-related helpers

---

# `rectifier-shared.yaml`

Owns cross-unit charger state and orchestration.

Responsibilities include:

* encoder UI state
* per-unit lifecycle
* discovery queue
* discovery serialization
* effective current capability
* current scaling
* thermal derating
* blackstart scripts
* polling schedulers
* reconnect probing
* TWAI recovery
* aggregate/shared control logic

---

# Rectifier lifecycle

Per-unit lifecycle:

```text
OFFLINE
DISCOVERING
ONLINE
```

Normal connectivity timeout:

```text
3 seconds
```

During `DISCOVERING`:

```text
7 seconds
```

The longer discovery watchdog accommodates the intentional 5-second stabilization period.

Discovery waits for TWAI:

```text
RUNNING
```

Time spent in BUS_OFF/recovery does not consume normal discovery attempts.

---

# Discovery sequence

Per unit:

```text
CAN detected
    ↓
DISCOVERING
    ↓
stabilization
    ↓
static properties
    ↓
maximum-current capability
    ↓
address/shelf information
    ↓
verification
    ↓
targeted active-setpoint restore
    ↓
ONLINE
```

The static property response can contain many frames.

TWAI RX queue:

```text
64 frames
```

A physically observed property response contained:

```text
56 frames
```

---

# Current capability

Absolute project ceiling:

```text
75 A
```

If a reachable rectifier has unknown capability:

```text
effective current limit = 50 A
```

Once all reachable capabilities are known:

```text
effective current limit
    =
min(
    75 A,
    lowest reachable capability
)
```

Command scaling uses the highest known reachable capability once all reachable capabilities are available.

Current limiting and command scaling are intentionally separate concepts.

---

# Thermal protection

Applied current:

```text
min(
    requested current,
    hardware capability,
    thermal limit
)
```

Thermal states:

| State     |     Enter | Recovery |                Current |
| --------- | --------: | -------: | ---------------------: |
| NORMAL    |  `<70 °C` |        — | hardware/project limit |
| WARNING_1 | `>=70 °C` | `<65 °C` |                   50 A |
| WARNING_2 | `>=80 °C` | `<75 °C` |                   30 A |
| LOCKOUT   | `>=90 °C` | `<80 °C` |         individual OFF |

Stale temperature data never relaxes thermal protection.

Recovery from lockout never automatically turns the rectifier back on.

---

# `rectifier-can/`

Contains parameterized CAN receive handlers.

## `property-start.yaml`

Handles the start of the multi-frame static property response.

## `property-end.yaml`

Handles property completion and reconstructed property parsing.

## `cyclic-telemetry.yaml`

Decodes normal cyclic rectifier telemetry.

## `fan-telemetry.yaml`

Decodes internal R4875G1 fan telemetry.

## `address-data.yaml`

Handles capability/address-related discovery data.

## `power-state.yaml`

Handles rectifier power-state/status frames.

---

# CAN transmission policy

Normal ESPHome CAN transmission is used for:

* online telemetry polling
* internal fan polling
* property discovery
* capability/address discovery
* active setpoints
* reconnect setpoint restore
* ON/OFF control

TWAI Single-Shot is reserved for:

```text
slow OFFLINE reconnect probes
```

This prevents absent rectifiers from causing repeated automatic retransmission of unacknowledged probe frames.

---

# Deployment boundary

`scripts/deploy-ha.ps1` manages:

```text
r4875g1-3phase-charger.yaml
packages/**/*.yaml
```

It intentionally does **not** deploy:

```text
packages/README.md
README.md
other non-YAML files
```

The deployment process uses:

* remote staging
* SHA-256 verification
* optional backups
* installed-file verification
* staging cleanup

---

# Change discipline

Preserve unless explicitly changing them:

* public ESPHome IDs
* Home Assistant entity names
* CAN identifiers
* CAN payload formats
* protocol scaling
* timing/order requirements
* lifecycle transitions
* requested/applied-current semantics
* thermal thresholds
* blackstart safety behavior

Firmware version convention:

```text
normal program commit -> PATCH +1
documentation-only commit -> version unchanged
repository cleanup only -> version unchanged
release -> MINOR/MAJOR may advance
```

README documentation must remain synchronized with documented software behavior.

Commit messages should contain:

1. concise descriptive subject;
2. detailed bullet list of important changes and effects.

---

# Validation

Before committing meaningful firmware changes:

```text
git diff --check
esphome config r4875g1-3phase-charger.yaml
esphome compile r4875g1-3phase-charger.yaml
```

For display/encoder changes, also verify the physical TFT.

For cooling changes, verify physical fan behavior when the external fan hardware is installed.

For PowerShell tooling changes, perform at least a parser check or `-DryRun`.

---

# Current development status

Stable release:

```text
v4.3.0
main
```

The v4.3.0 encoder implementation has been hardware-tested for:

* Dashboard SELECT
* Dashboard EDIT
* temporary value buffering
* confirmation/commit
* double-click suppression in EDIT
* long-press suppression in EDIT
* Cooling Automatic selection/edit
* Cooling manual Fan Power
* Cooling manual PWM
* automatic-mode restriction of manual Cooling parameters
* page-aware footer behavior
* read-only Rectifiers/System behavior

The current feature branch is therefore functionally ready for release after repository cleanup and documentation synchronization.

---

# Release preparation

Before promoting the current feature branch to the next stable release:

1. remove obsolete temporary GitHub Actions workflows;
2. verify `README.md` and `packages/README.md`;
3. run `git diff --check`;
4. validate the ESPHome configuration;
5. compile the complete firmware;
6. optionally perform one final physical TFT smoke test;
7. create the release version commit;
8. promote the tested feature branch to `main`.

