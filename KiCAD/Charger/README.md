# R4875G1 3-Phase Charger – KiCad Project

This directory contains the KiCad schematic and PCB design for the hardware used by the R4875G1 3-phase charger controller.

## Controller Hardware

The current controller board is an **Espressif ESP32-S3-DevKitC-1** fitted with an **ESP32-S3-WROOM-1-N16R8** module (16 MB Quad-SPI flash, 8 MB Octal-SPI PSRAM).

The KiCad schematic uses the `PCM_Espressif:ESP32-S3-DevKitC` symbol/footprint. The firmware now uses the centralized DevKitC-1 GPIO map shown below. The schematic/PCB fan-interface wiring should follow these same net assignments.

Current GPIO map:

| Function | GPIOs |
|---|---|
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

## External Libraries

The project uses symbols, footprints and/or 3D models from the official Espressif KiCad Libraries:

https://github.com/espressif/kicad-libraries

The Espressif KiCad Libraries are licensed separately under the **Creative Commons CC BY-SA 4.0 License with the exception stated by Espressif**. See the upstream repository for the complete license terms.

## License

The charger PCB design and project files in this repository are licensed under the **MIT License**, unless otherwise noted.

Third-party library files remain subject to their respective upstream licenses.
