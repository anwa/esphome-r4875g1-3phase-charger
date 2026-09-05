# Documentation Maintenance

Documentation is part of the implementation and must describe the current project accurately.

## Language

All project documentation MUST be written in English.

This includes README files, architecture documentation, hardware documentation, repository rules and documentation embedded in source files.

The language used in development discussions does not affect this requirement.

## README Responsibilities

The root `README.md` SHOULD describe the project from a user's and integrator's perspective.

It SHOULD include, where relevant:

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

The README SHOULD NOT become a chronological development diary.

## Package Documentation

Detailed implementation architecture MAY be documented closer to the source, for example in `packages/README.md`.

Package documentation SHOULD explain:

- package responsibilities
- important dependencies
- ownership boundaries
- shared vs. per-unit behavior
- important data/control paths

## Keep Documentation Current

When a functional change makes existing documentation incorrect, update the documentation as part of the same feature or immediately following it.

Examples:

- moving runtime ownership to another file
- adding hardware
- changing GPIO assignments
- changing controls
- adding sensors
- changing supported operating behavior

## Current Architecture, Not Migration History

Permanent documentation SHOULD describe how the current system works.

Avoid statements such as:

- "Part 1"
- "Part 2"
- "temporary"
- "will later"
- "restored from v4"
- "during migration"

unless that historical context remains necessary.

Git history already records how the implementation evolved.

## Avoid Duplication

Do not maintain the same detailed information independently in multiple places unless there is a strong usability reason.

Prefer one authoritative detailed description and shorter references elsewhere.

## Hardware Documentation

Hardware documentation SHOULD distinguish clearly between:

- onboard hardware
- external hardware
- currently implemented hardware
- optional hardware

Do not describe implemented hardware as "planned".

## Comments vs. README

Use source comments for implementation-local information.

Use README documentation for information a reader needs without opening the implementation.

Do not move every implementation detail into the README.

## Documentation-Only Commits

Documentation-only changes do not require a firmware version bump.

They SHOULD be clearly identifiable from the commit message.
