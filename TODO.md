# Project TODO

This file tracks current unfinished work for the primary V6 charger generation. It is a working backlog, not a changelog. Completed items should be removed or reflected in the appropriate permanent documentation rather than retained as development history.

## Priority Legend

- **P0** — blocker or reliability issue that should be understood before dependent work continues
- **P1** — next functional or correctness work
- **P2** — planned improvement or design decision
- **P3** — deferred, external-dependency or long-term work

## P1 — Backup Blackstart Acceptance Validation

The backup rotary encoder now uses direct ESP32-S3 GPIOs and reuses the authoritative Charger Controller command paths. Before treating the next V6 milestone as a release checkpoint, validate the intended degraded-operation behavior explicitly.

- [ ] Verify DC-voltage and nominal DC sum-power editing with Wi-Fi, Home Assistant and MQTT unavailable.
- [ ] Verify long-press charger START/STOP with network services unavailable.
- [ ] Verify that touchscreen interaction is not required for the encoder state machine or command path.
- [ ] Verify that the 15-second edit timeout discards pending values without changing active setpoints.

## P2 — MCP23017 Fan Tachometer Margin Validation

The MCP23017 is now reserved for external cooling-fan power and Fan 1 / Fan 2 tachometer inputs on GPA0–GPA2. INTA and INTB are intentionally unconnected.

- [ ] Verify Cooling Fan 1 and Cooling Fan 2 tachometer readings at the maximum expected fan speed.
- [ ] Perform sustained high-speed fan runtime testing to confirm the non-interrupt MCP23017 input path has sufficient pulse-capture margin.

## P1 — Optional Motion-Wake Fallback Validation

Motion-based display wake is intentionally optional per target. Both current targets use a Home Assistant motion source, so the no-motion configuration still needs an explicit validation pass.

- [ ] Build a V6 target with the `display_motion` package omitted.
- [ ] Verify that the original LVGL idle-timeout behavior remains active without a motion source.
- [ ] Verify that touching a sleeping display still wakes it without activating the control underneath the wake-up touch.
- [ ] Confirm that no dummy Home Assistant entity or target-specific workaround is required when motion wake is disabled.

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
