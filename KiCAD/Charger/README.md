# R4875G1 3-Phase Charger – KiCad Project

This directory contains the KiCad schematic and PCB design for the hardware used by the R4875G1 3-phase charger controller.

## Controller Hardware

The current controller board is an **Espressif ESP32-S3-DevKitC-1** fitted with an **ESP32-S3-WROOM-1-N16R8** module (16 MB Quad-SPI flash, 8 MB Octal-SPI PSRAM).

The KiCad schematic already uses the `PCM_Espressif:ESP32-S3-DevKitC` symbol/footprint. The firmware GPIO allocation is compatible with the DevKitC-1 headers and does not require reassignment.

Current GPIO map:

| Function | GPIOs |
|---|---|
| CAN / TWAI | 15, 16 |
| Rotary encoder | 17, 18 |
| Encoder push button | 2 |
| I2C / AHT10 | 9, 10 |
| TFT SPI | 11, 12, 13 |
| TFT CS / RESET / DC | 5, 6, 7 |
| TFT backlight PWM | 4 |

## External Libraries

The project uses symbols, footprints and/or 3D models from the official Espressif KiCad Libraries:

https://github.com/espressif/kicad-libraries

The Espressif KiCad Libraries are licensed separately under the **Creative Commons CC BY-SA 4.0 License with the exception stated by Espressif**. See the upstream repository for the complete license terms.

## License

The charger PCB design and project files in this repository are licensed under the **MIT License**, unless otherwise noted.

Third-party library files remain subject to their respective upstream licenses.
