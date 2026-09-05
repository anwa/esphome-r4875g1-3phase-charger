# Firmware Versioning

This project uses semantic-style firmware versions:

`MAJOR.MINOR.PATCH`

The canonical firmware version is defined in:

`packages/version.yaml`

No other file should contain an independently maintained current firmware version.

## Single Source of Truth

Firmware and UI version displays MUST reference `firmware_version` from `packages/version.yaml`.

Do not duplicate the current version as a hard-coded value elsewhere.

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

Example:

`4.x -> 5.0.0`

MAJOR changes are exceptional and should be planned explicitly.

## Documentation-Only Changes

Do NOT bump the firmware version for changes that do not alter the generated firmware behavior.

Examples:

- README updates
- repository rules
- comment-only cleanup
- documentation corrections
- Git housekeeping

A sequence of documentation commits may therefore retain the same firmware version.

## Version Bump Timing

The version SHOULD be updated in the same commit as the functional change that creates that firmware version.

Do not create arbitrary version bumps merely because another Git commit exists.

## Tested Releases

A version number indicates a firmware state, but not automatically a released or tagged build.

A Git tag SHOULD only be created after the intended release state has been tested sufficiently for its risk level.

## Tags

Release tags use:

`vMAJOR.MINOR.PATCH`

Example:

`v5.3.6`

Tags MUST point to the intended release commit.

Do not move an existing published release tag to unrelated history.
