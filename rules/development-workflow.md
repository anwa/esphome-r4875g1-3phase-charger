# Development Workflow

This rule adds the repository-specific development conventions. The general working style (one concern per change, inspect before editing, architectural consistency, evidence) and the ESPHome validation stages are defined by the inherited workspace rules.

## Functional Changes in This Firmware

The following count as functional changes and are never made as a side effect of cleanup:

- entity changes
- timing changes
- control-flow changes
- hardware configuration changes
- CAN behavior changes
- display behavior changes
- safety behavior changes

## Reuse Existing Architecture

Prefer the existing project abstractions over parallel implementations, for example:

- the shared rectifier scripts
- the substitutions for project limits
- the page-specific display runtimes
- the CAN capability state

Components of the same functional family follow the same structural pattern, ownership model, styling approach and state-management strategy, for example:

- dialogs and modal overlays
- page-specific display runtimes
- shared UI state
- aggregate telemetry
- charger-wide controls
- per-unit rectifier behavior
- hardware abstractions

## Keep Ownership Clear

| Behavior | Owner |
|---|---|
| page layout | `display/pages/` |
| page runtime | the corresponding `display/*.yaml` |
| persistent header runtime | `display/header.yaml` |
| shared command state | `display/command-state.yaml` |
| per-unit rectifier behavior | the parameterized rectifier package |
| shared rectifier behavior | the shared rectifier package |

## Multi-Target Firmware Development

When the active firmware generation contains multiple targets, shared and target-specific responsibilities MUST remain explicit. The target architecture is defined in `rules/firmware-targets.md`.

- Shared code contains behavior that is genuinely common to all participating targets.
- Target-specific hardware access, telemetry acquisition and command transport stay behind target-specific ownership boundaries.
- A shared HMI implementation depends on a target-neutral UI model, not on controller-only or Remote-HMI-only transport entities.
- When modifying shared UI or shared UI-model behavior, inspect the effect on every active target that consumes it.
- Do not solve a target-specific problem with widespread target-condition checks in common code when a backend or composition boundary can preserve the shared architecture.
- When a shared interface changes, update all affected target backends in the same coherent development step unless an explicitly planned intermediate compatibility layer is required.

## Validation Scope

Validation follows the stages of the inherited ESPHome rules. The scope depends on ownership:

- shared UI or shared UI-model change: validate and compile every consuming target
- Charger-Controller-specific change: validate and compile the Charger Controller
- Remote-HMI-specific change: validate and compile the Remote HMI
- shared target contract change: validate and compile all affected targets

Before merging a release-level V6 change, both V6 targets MUST compile successfully.

## Safety-Critical Behavior

Existing safety limits, thermal protection, CAN communication watchdogs and capability limits MUST NOT be weakened as a side effect of refactoring. If a cleanup exposes questionable safety behavior, report it explicitly instead of silently redefining it.
