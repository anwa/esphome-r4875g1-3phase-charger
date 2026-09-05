# R4875G1 3-Phase Charger – V4 KiCad Hardware

This directory contains the KiCad schematic and PCB design for the V4 hardware generation of the R4875G1 three-phase charger controller.

> [!IMPORTANT]
> This KiCad project does **not** represent the current V5 controller hardware.
>
> The current V5 firmware targets the Waveshare ESP32-S3-Touch-LCD-7 and uses a substantially different display, CAN and external-I/O architecture.
>
> The V4 hardware remains a maintained hardware variant on the `v4-maintenance` branch.

## V4 Controller Hardware

The V4 controller is based on an **Espressif ESP32-S3-DevKitC-1** fitted with an **ESP32-S3-WROOM-1-N16R8** module with 16 MB Flash and 8 MB PSRAM.

The KiCad schematic uses the `PCM_Espressif:ESP32-S3-DevKitC` symbol and footprint.

The design includes the hardware required by the V4 controller architecture, including the external display, CAN interface, rotary encoder and chassis-fan connections.

## V4 GPIO Map

The KiCad design uses the following V4 controller assignments:

| Function | GPIOs |
|---|---:|
| Encoder push button | 2 |
| TFT backlight PWM | 4 |
| TFT CS / RESET / DC | 5, 6, 7 |
| I2C SDA / SCL | 8, 9 |
| TFT SPI MOSI / MISO / CLK | 11, 12, 13 |
| CAN / TWAI TX / RX | 15, 16 |
| Rotary encoder A / B | 17, 18 |
| FAN_ENABLE | 21 |
| FAN3_TACH / FAN2_TACH / FAN1_TACH | 39, 40, 41 |
| FAN_PWM | 42 |

These assignments describe the V4 KiCad hardware and MUST NOT be used as the GPIO map for the current V5 firmware.

## V5 Hardware

The current V5 controller uses the **Waveshare ESP32-S3-Touch-LCD-7** as its hardware platform.

Important architectural differences include:

| Function | V4 KiCad hardware | V5 hardware |
|---|---|---|
| Controller | ESP32-S3-DevKitC-1 | Waveshare ESP32-S3-Touch-LCD-7 |
| Display | External ILI9488 over SPI | Onboard 800×480 RGB LCD |
| Touch | None | GT911 capacitive touch |
| CAN | External CAN interface | Onboard CAN transceiver |
| Rotary encoder | Direct ESP32 GPIOs | MCP23017 |
| External fan enable | Direct ESP32 GPIO | MCP23017 |
| Fan 1 / Fan 2 tachometer | Direct ESP32 GPIOs | MCP23017 |
| Fan 3 tachometer | Direct ESP32 GPIO | EMC2101 |
| External fan PWM | ESP32 PWM | EMC2101 |
| External I2C expansion | None | TCA9548A |

The V5 hardware architecture is documented in the repository root `README.md` and `packages/README.md`.

A V5 KiCad design should be maintained as a separate hardware design rather than modifying this V4 project in place.

## Project Files

```text
Charger.kicad_pro
    KiCad project configuration

Charger.kicad_sch
    main V4 controller schematic

fan-control.kicad_sch
    external fan-control schematic

Charger.kicad_pcb
    V4 PCB layout
```

## External Libraries

The project uses symbols, footprints and/or 3D models from the official Espressif KiCad Libraries:

`https://github.com/espressif/kicad-libraries`

The Espressif KiCad Libraries are licensed separately under the **Creative Commons CC BY-SA 4.0 License with the exception stated by Espressif**. See the upstream repository for the complete license terms.

## License

The charger PCB design and project files in this repository are licensed under the **MIT License**, unless otherwise noted.

Third-party library files remain subject to their respective upstream licenses.
