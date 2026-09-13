# Project TODO

This file tracks current unfinished work for the primary V6 charger generation. It is a working backlog, not a changelog. Completed items should be removed or reflected in the appropriate permanent documentation rather than retained as development history.

## Priority Legend

- **P0** — blocker or reliability issue that should be understood before dependent work continues
- **P1** — next functional or correctness work
- **P2** — planned improvement or design decision
- **P3** — deferred, external-dependency or long-term work

## P0 — MCP23017 Reliability and Input Capture

The Charger Controller currently depends on the MCP23017 for the backup rotary encoder, external cooling-fan power enable and Cooling Fan 1 / Fan 2 tachometer inputs. Resolve the current MCP23017 problem before adding more behavior on top of these inputs.

- [ ] Reproduce the current MCP23017 problem on the current V6 Charger Controller firmware.
- [ ] Isolate the root cause without changing multiple suspected causes at the same time.
- [ ] Verify stable operation of encoder A, encoder B and encoder push-button inputs.
- [ ] Verify stable operation of the external cooling-fan enable output.
- [ ] Verify Cooling Fan 1 and Cooling Fan 2 tachometer inputs across the expected RPM range.
- [ ] Determine whether MCP23017-polled tachometer inputs can reliably capture the required pulse rate at high fan speed.
- [ ] If the tachometer path is not reliable enough, choose one consistent replacement architecture instead of adding per-fan workarounds.
- [ ] Perform sustained runtime testing after the MCP23017 issue is resolved.

## P1 — V6 Documentation Consistency

Some detailed documentation still describes V5 as the current generation even though `main` now contains the V6 dual-target architecture.

- [ ] Update `R4875G1_CONTROL_FLOWS.md` from the old current-V5 description to the current V6 architecture.
- [ ] Review `R4875G1_CONTROL_FLOWS.md` for remaining single-target assumptions, especially hardware ownership, HMI ownership and backup-encoder wording.
- [ ] Update `KiCAD/Charger/README.md` so the V4 KiCad project is compared with the current V6 hardware rather than the former V5 primary generation.
- [ ] Search the current `main` branch for remaining stale `current V5` references after the documentation cleanup.
- [ ] Keep this cleanup documentation-only and do not bump the firmware version.

## P1 — Backup Rotary Encoder and Local Blackstart Controls

This work is blocked by the MCP23017 reliability investigation above. The touchscreen remains the primary HMI; the rotary encoder is intended as a local backup control path.

- [ ] Define the final encoder interaction model before implementing control actions.
- [ ] Provide local adjustment of the DC voltage target.
- [ ] Provide local adjustment of the nominal DC sum-power target.
- [ ] Provide a deliberate local charger START/STOP interaction suitable for blackstart use.
- [ ] Route encoder actions through the existing authoritative Charger Controller command/control paths rather than introducing a second CAN or safety implementation.
- [ ] Preserve all existing START eligibility, thermal, lifecycle and capability checks.
- [ ] Ensure the encoder control path remains usable without Wi-Fi, Home Assistant, MQTT or Internet access.
- [ ] Validate blackstart operation with network services unavailable.

## P1 — Optional Motion-Wake Fallback Validation

Motion-based display wake is intentionally optional per target. Both current targets use a Home Assistant motion source, so the no-motion configuration still needs an explicit validation pass.

- [ ] Build a V6 target with the `display_motion` package omitted.
- [ ] Verify that the original LVGL idle-timeout behavior remains active without a motion source.
- [ ] Verify that touching a sleeping display still wakes it without activating the control underneath the wake-up touch.
- [ ] Confirm that no dummy Home Assistant entity or target-specific workaround is required when motion wake is disabled.

## P1 — Extend Trends History to 15 Minutes

The current shared Trends implementation stores 120 samples per trend at a five-second interval, providing ten minutes of local history. Extending this to 180 samples provides fifteen minutes while adding only a small amount of memory usage.

- [ ] Increase all five local trend ring buffers from 120 to 180 samples.
- [ ] Keep the existing five-second sampling interval.
- [ ] Increase the native LVGL chart point count from 120 to 180.
- [ ] Change the fixed X-axis labels to `-15 min`, `-10 min`, `-5 min` and `now`.
- [ ] Position the four time labels evenly across the chart width and align the vertical grid divisions with the five-minute intervals.
- [ ] Preserve NAN gaps for unavailable telemetry.
- [ ] Verify current, minimum and maximum calculations across the full fifteen-minute history.
- [ ] Validate and compile both V6 targets because Trends is shared HMI runtime.
- [ ] Check heap, largest free heap block and sustained runtime stability after the larger chart is created lazily.

## P2 — Final Per-Target Motion Sensor Configuration

The two current V6 targets temporarily use the same Home Assistant occupancy entity. The architecture already supports independent target-specific entity IDs.

- [ ] Assign the final Charger Controller motion/occupancy entity when its installation location is finalized.
- [ ] Assign the final Remote HMI motion/occupancy entity when its installation location is finalized.
- [ ] Tune `display_idle_timeout` independently for each target based on the actual sensor hold time and desired user experience.

## P2 — Reduced-Rectifier Power-Target Strategy

The nominal DC sum-power calculation intentionally divides the configured target by three. If one or two rectifiers are unavailable, the remaining units do not automatically increase current to compensate.

- [ ] Decide whether the fixed three-unit divisor should remain the permanent safety/behavior policy.
- [ ] If power redistribution is desired, define the behavior explicitly for three, two and one available rectifier before changing the implementation.
- [ ] Ensure any redistribution remains bounded by per-unit hardware capability, effective current limit, thermal derating and AC-side constraints.
- [ ] Avoid automatic current jumps that could surprise the operator when rectifier availability changes.
- [ ] Update `R4875G1_CONTROL_FLOWS.md` together with any functional change to this policy.

## P2 — Mechanical Design Completion

The current FreeCAD model provides the front, middle and back holders but the complete charger enclosure is still work in progress.

- [ ] Add the rear connection / wiring compartment.
- [ ] Add mounting for the cooling fans.
- [ ] Add final cable-routing features.
- [ ] Complete final mounting and enclosure details.
- [ ] Re-check clearances and service access after the electrical layout is finalized.

## P3 — ESP32-S3 Flash / PSRAM Performance

The Waveshare platform is currently kept at the supported 80 MHz Flash / 80 MHz Octal PSRAM configuration. The documented 120 MHz option should remain deferred until ESPHome and ESP-IDF support it cleanly.

- [ ] Re-evaluate 120 MHz Flash / Octal PSRAM when stable ESPHome support becomes available.
- [ ] Do not enable unsupported or experimental production overrides merely to reach 120 MHz.
- [ ] Benchmark LVGL responsiveness, free heap, largest free heap block and runtime stability before and after any future change.

## P3 — Home Assistant Deployment Transport

The deployment script already retries file transfers, but intermittent SSH deployment timeouts have previously occurred outside the script's control.

- [ ] Reproduce the intermittent Home Assistant SSH deployment timeout if it still occurs.
- [ ] Identify the root cause instead of relying only on retry behavior.
- [ ] Keep deployment retries as resilience, not as a substitute for resolving a reproducible transport problem.
