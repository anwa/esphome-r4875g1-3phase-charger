# Repository Rules

This directory contains the rules that are specific to this repository. They are written for AI coding agents and remain readable for human contributors.

Shared rules are inherited from the workspace rule hierarchy listed in `AGENTS.md`: language, Git authority, branches, commits, versioning principles, documentation style, the ESPHome toolchain, YAML comments and the Waveshare hardware and UI conventions. They are not repeated here.

## Rules

| File | Purpose |
|---|---|
| `development-workflow.md` | Architecture reuse, ownership and validation scope for this firmware |
| `firmware-targets.md` | Multi-target firmware architecture, ownership and validation |
| `versioning.md` | Firmware versioning and version-bump policy |
| `documentation.md` | README, package and multi-target documentation |
| `git-workflow.md` | Maintenance branches, merge checklist and release tags |
| `local-validation.md` | Validation script, validation scope and contract check |

## Precedence

Explicit instructions for the current task come first, then these repository rules, then the inherited workspace rules, then existing implementation patterns.

## Updating Rules

A rule that applies to other repositories as well belongs in the workspace rule hierarchy, not here.

Rule changes are committed separately from firmware changes when practical and do not bump the firmware version.
