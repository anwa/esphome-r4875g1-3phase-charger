# Firmware Targets

This rule defines the multi-target firmware architecture used by the current project generation.

The repository supports multiple firmware targets that share presentation and application concepts while retaining clearly separated hardware, data-source and command-transport responsibilities.

## V6 Firmware Targets

V6 consists of two coordinated firmware targets:

### Charger Controller

The Charger Controller is physically attached to the charger.

It owns:

- Huawei rectifier CAN communication
- rectifier lifecycle and discovery
- charger setpoints and command execution
- local charger-side sensors and peripherals
- thermal protection and safety logic
- local blackstart capability
- the locally attached touchscreen HMI

The Charger Controller MUST remain operational without Home Assistant, MQTT, Wi-Fi or Internet access where existing local behavior supports this.

Home Assistant and other network services MUST NOT become dependencies of charger safety, CAN control, START/STOP eligibility or blackstart operation.

### Remote HMI

The Remote HMI uses the same display/controller hardware platform but is not physically connected to charger-side CAN or external charger peripherals.

It obtains charger telemetry and state through Home Assistant and sends user command requests back through Home Assistant.

The Remote HMI:

- MUST NOT duplicate charger safety logic
- MUST NOT send CAN commands directly
- MUST NOT determine START eligibility independently
- MUST NOT treat a locally requested command as confirmed charger state
- MUST treat the Charger Controller as authoritative for charger state and command results
- MUST expose loss of the Home Assistant connection clearly
- MUST prevent unavailable remote communication from appearing as valid live charger state

The Remote HMI is a convenience interface and MUST NOT be treated as an independent blackstart or safety controller.

## Shared HMI Architecture

The Charger Controller and Remote HMI MUST use the same shared LVGL presentation implementation for screens whose user-visible behavior is intended to match.

Target-specific differences MUST be isolated behind target-specific backends, composition or explicitly target-specific UI fragments rather than by copying shared page files.

Shared HMI code includes, where practical:

- page layouts
- dialogs
- themes
- styles
- navigation
- widget presentation
- page-specific rendering logic
- shared command-state presentation

Target-specific data acquisition and command transport MUST NOT be duplicated inside shared LVGL page implementations.

Instead, shared HMI code SHOULD consume a target-neutral UI model or interface.

Conceptually:

```text
                         Shared LVGL HMI
                               |
                               v
                       Shared UI model
                               |
                +--------------+--------------+
                |                             |
                v                             v
      Charger Controller backend       Remote HMI backend
                |                             |
                v                             v
       Local runtime / CAN          Home Assistant entities
                                              |
                                              v
                                   Charger Controller
```

## UI Model Boundary

Shared display code MUST NOT directly depend on target-specific transport details when a shared UI-model abstraction exists.

In particular, shared UI code SHOULD NOT directly depend on:

* CAN transport implementation
* controller-only hardware peripherals
* raw Home Assistant import entities
* Remote-HMI-only transport entities

Target backends SHOULD translate their native state into the shared UI model.

The goal is that a user-interface change can normally be implemented once and used by both targets without maintaining parallel page files.

## Command Boundary

Shared UI controls SHOULD express user intent rather than transport implementation.

For example, a shared START control should request a charger START operation through the active target backend.

On the Charger Controller, that backend may invoke the local charger-control path directly.

On the Remote HMI, that backend may invoke a Home Assistant action that ultimately reaches the Charger Controller.

The Charger Controller remains authoritative for:

* safety checks
* command acceptance
* command execution
* resulting charger state

The Remote HMI MUST NOT bypass this ownership boundary.

## State Authority

The Charger Controller is authoritative for charger operational state.

The Remote HMI SHOULD display state received back through Home Assistant rather than assuming that a requested command succeeded.

Optimistic state MAY be used only for purely local Remote-HMI presentation that cannot be mistaken for confirmed charger state.

## Connection Loss

Loss of Home Assistant connectivity on the Remote HMI MUST NOT leave remote charger controls appearing fully operational.

The Remote HMI SHOULD:

* expose the disconnected state clearly
* disable commands that cannot be delivered safely
* distinguish unavailable or stale state from valid live telemetry
* avoid converting unavailable data into artificial healthy or zero values

The Charger Controller MUST continue its local operation independently.

## Target Entry Points

Each firmware target SHOULD have its own root ESPHome configuration.

For V6 the intended structure is:

```text
r4875g1-3phase-charger.yaml
r4875g1-remote-hmi.yaml
```

The root configurations SHOULD compose target-specific hardware and backend packages together with shared packages.

Target identity SHOULD be selected by the root build configuration rather than by widespread runtime role checks throughout shared code.

## Target-Specific Hardware

Hardware that exists only on one target MUST remain owned by target-specific packages or composition.

The Remote HMI MUST NOT require charger-side peripherals merely because the Charger Controller uses them.

Examples of Charger-Controller-only hardware may include:

* CAN
* MCP23017 charger-side expansion
* AHT10 charger-compartment monitoring
* EMC2101 charger cooling
* charger-side rotary encoder wiring

Hardware physically shared by both target devices MAY remain in common packages when doing so preserves clear ownership.

## Validation

Once both V6 targets are buildable, a change to shared V6 UI, shared UI-model code or other shared runtime behavior MUST validate both V6 firmware targets.

At minimum:

1. validate ESPHome configuration for the Charger Controller
2. validate ESPHome configuration for the Remote HMI
3. compile both targets
4. perform appropriate runtime testing on every affected target

A target-specific change MUST validate and compile the affected target.

Once both V6 targets are buildable, a merge that changes shared target contracts MUST validate and compile both targets successfully.

## V6 Bootstrap and Staged Migration

The initial V6 architecture migration MAY use intermediate development checkpoints in which the Remote HMI target is not yet fully buildable.

This exception exists to preserve small, testable and reversible migration steps while the existing Charger Controller is moved behind the shared UI-model boundary and the Remote HMI backend is being introduced.

A bootstrap checkpoint:

- MUST remain on the V6 development branch
- MUST preserve a working and testable Charger Controller when the changed checkpoint affects it
- SHOULD identify the temporary target limitation in the commit message or development plan
- MUST continue toward a buildable dual-target architecture
- MUST NOT be treated as a complete V6 release state
- MUST NOT replace the primary generation on `main` while either V6 target is incomplete

Once both V6 root targets are buildable and consume production shared UI code, changes to shared UI, the shared UI model or shared target contracts MUST validate and compile both targets.

Before V6 replaces the primary firmware generation on `main`, both the Charger Controller and Remote HMI targets MUST validate and compile successfully, and appropriate runtime testing MUST have been completed for the affected behavior.

## Cross-Target Compatibility

Changes to the shared UI-model contract MUST consider both backends in the same development step.

Do not change a shared entity contract for one target while knowingly leaving the other target incompatible.

When a shared model change requires staged migration, preserve independently working checkpoints and document the temporary compatibility boundary in the development branch rather than leaving permanent migration comments in production files.
