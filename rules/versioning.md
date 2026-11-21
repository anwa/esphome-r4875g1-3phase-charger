# Firmware Versioning

This project uses semantic-style firmware versions:

`MAJOR.MINOR.PATCH`

The canonical firmware version is defined in:

`packages/version.yaml`

No other file should contain an independently maintained current firmware version.

## Single Source of Truth

Firmware and UI version displays MUST reference `firmware_version` from `packages/version.yaml`.

Do not duplicate the current version as a hard-coded value elsewhere.

## Multi-Target Generation Versioning

All firmware targets that belong to the same current firmware generation share one generation version unless the architecture is explicitly changed to support independently versioned products.

For V6, the Charger Controller and Remote HMI use the same firmware version.

Both targets MUST consume the canonical version from:

```text
packages/version.yaml
```

The two targets MAY use different ESPHome device names, friendly names and project identifiers, but they MUST NOT maintain independent V6 firmware-version constants.

A V6 release therefore identifies one compatible repository state containing both targets.

Maintenance branches retain their own branch-local version history.

For example:

```text
main / V6        -> V6 version history
v5-maintenance   -> V5 version history
v4-maintenance   -> V4 version history
```

A maintenance release does not change the version of another branch.

## PATCH Version

Increment PATCH for normal tested firmware changes that alter the shipped firmware implementation.

Examples:

- bug fixes
- UI behavior changes
- sensor additions
- runtime refactors
- hardware-support changes
- internal implementation improvements included in the firmware

Example:

`5.3.5 -> 5.3.6`

## MINOR Version

Increment MINOR for a meaningful new feature set or substantial milestone while maintaining the same overall firmware generation.

Examples:

- a substantial new controller feature
- completion of a major UI capability
- a significant new hardware capability

Example:

`5.3.x -> 5.4.0`

A MINOR release resets PATCH to zero.

## MAJOR Version

Increment MAJOR for a new firmware generation or intentionally incompatible architecture.

Examples include:

- a new hardware generation
- a fundamental firmware architecture change
- introduction of a coordinated multi-target architecture

Example:

`5.x -> 6.0.0`

MAJOR changes are exceptional and should be planned explicitly.

The V6 dual-target architecture starts at `6.0.0` when the first functional V6 firmware state is created. Rule-only and documentation-only preparation for V6 does not itself require a firmware version bump.

## Bumps, Tags and Documentation-Only Changes

Version-bump timing, documentation-only changes and tag format follow the inherited workspace rules. Which versions get a release tag is defined in `rules/git-workflow.md`.
