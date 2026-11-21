# Documentation Maintenance

This rule adds the repository-specific documentation conventions. Language, Markdown wrapping, current-state wording and duplication rules are defined by the inherited workspace rules.

## README Responsibilities

The root `README.md` describes the project from a user's and integrator's perspective. It SHOULD include, where relevant:

- project purpose
- supported hardware
- major features
- architecture overview
- installation or deployment
- hardware connections
- Home Assistant / MQTT integration
- controls and telemetry
- safety behavior
- limitations
- links to more detailed documentation

## Package Documentation

Detailed implementation architecture is documented closer to the source, in `packages/README.md`. It SHOULD explain:

- package responsibilities
- important dependencies
- ownership boundaries
- shared vs. per-unit behavior
- important data and control paths

## Multi-Target Documentation

When the current firmware generation contains multiple targets, documentation MUST distinguish clearly between:

```text
shared generation behavior
Charger Controller behavior
Remote HMI behavior
```

Do not describe target-specific hardware or behavior as if it exists on every target.

The root README SHOULD explain the user-visible purpose and relationship of the firmware targets.

Detailed package documentation SHOULD describe:

- shared packages
- target-specific packages
- backend ownership
- shared UI-model boundaries
- target-specific hardware
- target-specific data and command paths

Shared UI behavior SHOULD be documented once where practical rather than duplicated for each target.

Documentation for the Remote HMI MUST make clear that:

- charger state is obtained through Home Assistant
- charger commands are transported through Home Assistant
- the Charger Controller remains authoritative for charger safety and command execution
- the Remote HMI is not an independent blackstart or safety controller

## Keep Documentation Current

Examples of functional changes that require a documentation update in the same change:

- moving runtime ownership to another file
- adding hardware
- changing GPIO assignments
- changing controls
- adding sensors
- changing supported operating behavior

## Hardware Documentation

Hardware documentation distinguishes clearly between onboard hardware, external hardware, currently implemented hardware and optional hardware. Do not describe implemented hardware as "planned".
