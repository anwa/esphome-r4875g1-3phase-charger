# 3-Phase Huawei R4875G1 Battery Charger Controller

ESPHome controller for **three Huawei R4875G1 rectifiers** operated as a coordinated three-phase battery charger with a common parallel DC output.

**Current development firmware: 4.0.10** on branch `v4-lvgl-menu`.

Version 4 keeps the validated charger, CAN-recovery, thermal-protection and local-blackstart model from v3 and uses an **LVGL-based local TFT interface**. The current development branch is splitting that interface into four dedicated pages while keeping CAN/control behavior outside the display layer.

For detailed runtime behavior, see `R4875G1_CONTROL_FLOWS.md`. Package ownership and maintenance rules are documented in `packages/README.md`.

> [!WARNING]
> This project controls mains-powered equipment and a high-current DC battery bus. Firmware is not a substitute for correctly engineered fuses, breakers, disconnects, BMS protection, earthing, isolation and conductor sizing.

## Project purpose

The intended installation uses one R4875G1 on each AC phase, all three DC outputs on one common battery/DC bus, identical DC voltage, a common per-unit current command and a nominal three-unit charging-power target. Core charger operation is local: Home Assistant, MQTT and Wi-Fi are useful interfaces but are not required for CAN control, the TFT/encoder or blackstart.

## System overview

```mermaid
flowchart TD
    AC[Three-phase AC source] -->|L1| U1[R4875G1 Unit 1]
    AC -->|L2| U2[R4875G1 Unit 2]
    AC -->|L3| U3[R4875G1 Unit 3]
    U1 --> DCBUS[Common DC bus / battery]
    U2 --> DCBUS
    U3 --> DCBUS
    U1 <--> CAN[Shared 125 kbit/s CAN]
    U2 <--> CAN
    U3 <--> CAN
    CAN <--> ESP[ESP32-S3 N16R8]
    ENC[Rotary encoder + button] --> ESP
    AHT[AHT10] --> ESP
    ESP --> TFT[ILI9488 + LVGL]
    ESP <--> HA[Home Assistant]
    ESP <--> MQTT[MQTT]
```

CAN uses 29-bit extended identifiers.

# Key features

## Charger control

- Three R4875G1 rectifiers controlled by one ESP32-S3.
- Common active DC voltage/current setpoints.
- Active setpoints routed only to verified `ONLINE` + CAN-fresh units.
- Individual and broadcast ON/OFF controls.
- Nominal three-unit power target with automatic current calculation.
- 50 A fail-safe capability ceiling until every reachable rectifier has fresh capability data.
- Effective current ceiling uses the lowest known reachable capability, capped at 75 A.
- Shared current command scaling uses the highest reachable capability once all reachable capabilities are known.
- Periodic active-setpoint refresh only to eligible online units.

## CAN reliability

- Independent per-unit raw-CAN watchdog.
- Normal watchdog timeout: 3 s.
- During `DISCOVERING`, the watchdog timeout is extended to 7 s so the intentional 5 s discovery-stabilization delay does not falsely mark the unit unreachable.
- Explicit lifecycle: `OFFLINE`, `DISCOVERING`, `ONLINE`.
- Fast telemetry/fan polling only for `ONLINE` units.
- Slow round-robin probing for `OFFLINE` units.
- TWAI Single-Shot restricted to slow OFFLINE reconnect probes.
- Discovery waits for TWAI to return to `RUNNING`; BUS_OFF/recovery wait time does not consume discovery retries.
- Serialized property/capability/address discovery.
- 64-frame TWAI RX queue for the multi-frame property response.
- Targeted active-setpoint restore before a rediscovered unit returns to `ONLINE`.
- TWAI BUS_OFF recovery as a final controller-level recovery mechanism.

## Local blackstart

Current implemented encoder behavior is:

- rotate: edit the selected DC voltage or nominal three-unit DC-power target;
- short press: select `Voltage` or `Power` editing;
- double press: advance to the next LVGL page (`Dashboard → Rectifiers → Cooling → System → Dashboard`);
- long press (≥3 s): START/STOP;
- STOP has priority and is unrestricted;
- START is issued only to units that are `ONLINE`, CAN-fresh, explicitly `OFF`, below the temperature trip threshold and not locked out.

Single-click recognition deliberately waits 350 ms after release so the first click of a double-click cannot also toggle the Voltage/Power edit mode.

## Thermal protection

Shared applied current is:

```text
min(requested current, effective hardware capability, thermal limit)
```

Thermal states use 70/80/90 °C thresholds with hysteresis. Warning stages reduce the shared current ceiling to 50 A and 30 A. At ≥90 °C the affected unit is switched off and locked out until a fresh temperature below 80 °C is received. Derating never overwrites the user's requested current.

# Firmware architecture

```text
r4875g1-3phase-charger.yaml
packages/
├── version.yaml
├── core.yaml
├── hardware.yaml
├── display.yaml
├── display/
│   ├── hardware.yaml
│   ├── theme.yaml
│   ├── ui.yaml
│   └── pages/
│       ├── dashboard.yaml
│       ├── rectifiers.yaml
│       ├── cooling.yaml
│       └── system.yaml
├── cooling.yaml
├── controls.yaml
├── rectifier-shared.yaml
├── rectifier-unit.yaml
└── rectifier-can/
    ├── property-start.yaml
    ├── property-end.yaml
    ├── cyclic-telemetry.yaml
    ├── fan-telemetry.yaml
    ├── address-data.yaml
    └── power-state.yaml
```

`r4875g1-3phase-charger.yaml` owns project-wide substitutions, package assembly, the three unit instances, boot behavior, encoder input and aggregate entities. `rectifier-unit.yaml` is instantiated three times. `rectifier-shared.yaml` owns cross-unit lifecycle/discovery/current/thermal logic and the single physical CAN controller.

The display stack is deliberately separated: hardware transport in `display/hardware.yaml`, shared LVGL/fonts/styles in `display/theme.yaml`, page aggregation in `display/ui.yaml`, and one file per screen in `display/pages/`.

# Versioning

The firmware version has one source of truth in `packages/version.yaml`:

```yaml
substitutions:
  firmware_version: "4.0.10"
```

`esphome.project.version` and the TFT consume `${firmware_version}`. Project convention: **every repository commit increments PATCH by one**.

# Hardware

## Main controller

- Espressif ESP32-S3-DevKitC-1
- ESP32-S3-WROOM-1-N16R8
- 16 MB Quad-SPI flash
- 8 MB Octal-SPI PSRAM
- ESP-IDF framework
- ESPHome minimum version: 2026.7.4

## GPIO map

| Function | GPIO |
|---|---:|
| Encoder button | 2 |
| TFT backlight | 4 |
| TFT CS / RESET / DC | 5 / 6 / 7 |
| I²C SDA / SCL | 8 / 9 |
| SPI MOSI / MISO / CLK | 11 / 12 / 13 |
| CAN TX / RX | 15 / 16 |
| Encoder A / B | 17 / 18 |
| External fan enable | 21 |
| Fan tach 3 / 2 / 1 | 39 / 40 / 41 |
| Fan PWM | 42 |

## CAN interface

- SN65HVD230 3.3 V transceiver
- 125 kbit/s
- 29-bit extended identifiers
- proper twisted-pair wiring, stable connector contacts, common reference and correct termination required

## ILI9488 / LVGL display

The physical panel is 480×320 over SPI. LVGL rotation `90` produces the default 320×480 portrait UI.

Current configuration:

- ESPHome `mipi_spi`, model ILI9488;
- 40 MHz SPI display data rate;
- 16-bit RGB565 color depth;
- LVGL full framebuffer (`buffer_size: 100%`) in PSRAM;
- default `display_rotation: 90`;
- Roboto 14/18/26 px fonts;
- scrolling disabled on the primary page/card layouts;
- 5-minute backlight inactivity timeout.

### Current four-page development UI

`Dashboard` is implemented as the compact operating overview: date/time and firmware, overall ON/OFF state, combined AC/DC summaries, available-unit count, highest output temperature, conversion efficiency and local Voltage/Power/Applied-current setpoints.

`Rectifiers` currently shows three cards (L1/L2/L3) with CAN fault state or power state plus DC voltage, current, power and output temperature. **Input temperature, internal fan, capability and lifecycle are not yet shown on this page.**

`Cooling` shows compartment temperature/humidity, external fan power, PWM command and external fan 1/2/3 RPM.

`System` currently shows firmware in the header, IP address, Wi-Fi RSSI, controller CPU temperature and CAN communication status for L1/L2/L3. **Uptime, heap and PSRAM are not yet displayed on this page**, although runtime diagnostic entities already exist in ESPHome.

`display/ui.yaml` enables LVGL `page_wrap` and includes the four page files. Encoder double-click uses `lvgl.page.next` with a short left transition and wraps from System back to Dashboard.

## AHT10 compartment sensor

The shared rear rectifier compartment uses an AHT10 at I²C address `0x38` for temperature and humidity.

## External cooling fans

External/chassis fans are independent from the R4875G1 internal fans. GPIO21 enables the common fan supply, GPIO42 provides shared 25 kHz PWM, and GPIO41/40/39 read fan 1/2/3 tachometer signals. Tach conversion assumes two pulses/revolution. Automatic temperature curves and fan-failure alarms are not implemented yet.

# Electrical / power-control model

All three rectifier outputs share the DC bus. The local nominal power selector uses:

```text
I_each = P_target / (3 × V_DC)
```

The divisor remains fixed at three even when fewer rectifiers are active. This intentionally avoids increasing current on remaining units when another unit disappears.

Capability handling is CAN-aware:

```text
startup/no reachable units               -> 50 A
reachable capability missing             -> 50 A
all reachable capabilities known         -> lowest reachable capability, max 75 A
command scaling when complete             -> 1024 / highest reachable capability
```

A disconnected unit is removed from these calculations. A reconnecting unit returns the shared limit to the 50 A fail-safe until its capability is freshly rediscovered.

# Rectifier lifecycle and reconnect

Every unit starts `OFFLINE`. A valid heartbeat triggers `DISCOVERING`; the discovery stabilization period is 5 seconds. During that state the connectivity watchdog allows 7 seconds instead of the normal 3 seconds. Serialized discovery reads static properties, maximum-current capability and address information. Before each discovery request, firmware waits for TWAI `RUNNING`; time spent in BUS_OFF/recovery does not consume a retry. Verification is followed by targeted active voltage/current restore, then the unit is promoted to `ONLINE`.

A continuously offline rectifier is probed approximately every 15 seconds. Physical testing has verified disconnect/reconnect recovery without ESP reboot and a complete 56-frame property response.

# Current capability and scaling

Maximum current is decoded from capability data in 0.5 A steps. The tested reduced-current connector configuration reported 52 A.

When all currently reachable capabilities are known, scaling uses the **highest reachable capability**, while the effective engineering-current ceiling uses the **lowest reachable capability**. If capability knowledge is incomplete, scaling falls back to `1024 / 75` and the effective ceiling remains 50 A.

`Rectifier Capability Mismatch` considers currently reachable units and is diagnostic rather than a direct charging inhibit.

# Telemetry

Per-unit telemetry includes AC/DC voltage, current and power, grid frequency, input/output temperature, operating hours, internal fan data, power state, maximum-current capability, address information and static identification properties.

CAN-aware aggregate entities include combined AC/DC power, combined DC current, average DC voltage, highest output temperature, conversion efficiency and available-unit count. Stale/unreachable measurements are excluded instead of being treated as valid zero values.

# Installation

Place the root YAML and the complete YAML package tree in the same ESPHome configuration directory and provide the required secrets. Do not commit real credentials.

Validate with:

```bash
esphome config r4875g1-3phase-charger.yaml
esphome compile r4875g1-3phase-charger.yaml
```

# Deploying to Home Assistant from Windows

The repository contains `scripts/setup-ha-ssh.ps1` and `scripts/deploy-ha.ps1`.

The deployment script:

- derives the destination YAML filename from `esphome.name`;
- reads the displayed firmware version from central `packages/version.yaml`;
- deploys the root project YAML plus **only `packages/**/*.yaml`**;
- does **not** deploy `packages/README.md` or other non-YAML files;
- stages uploads, verifies SHA-256 hashes, backs up currently managed target files and verifies installed hashes;
- leaves unrelated Home Assistant files untouched;
- supports `-DryRun` and `-NoBackup`.

The deployment stops after copying/verifying source files; ESPHome validation/installation remains an explicit step.

# Known limitations / current development status

- Optimized for three R4875G1 units.
- Nominal total-power calculation always divides by three.
- Capability mismatch is diagnostic and does not automatically disable charging.
- Mixed rectifier models/scaling behavior are not a primary supported configuration.
- Blackstart still requires power for ESP32/CAN electronics.
- SNTP date/time requires network synchronization after a cold start.
- External fan control has no automatic thermal curve or RPM-failure alarm yet.
- Rectifiers and System pages are intentionally incomplete compared with their planned final diagnostic content; the exact current content is listed above.
- Software does not replace hardware protection.

# Credits and license

The repository is distributed under the MIT License and builds on the Huawei R48xx CAN research published by `mjpalmowski` in the `CAN-BUS-control-R4875G1-with-ESPHome-and-MQTT` project.

Copyright (c) 2024 mjpalmowski  
Additional project development: Copyright (c) 2026 Andreas Wansner

# Documentation status

This README describes firmware **4.0.10** on development branch `v4-lvgl-menu` as implemented at this commit. It intentionally distinguishes implemented four-page UI content from the remaining menu/navigation work instead of documenting planned fields as already available.
