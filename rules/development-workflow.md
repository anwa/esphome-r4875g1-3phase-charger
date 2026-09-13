# Development Workflow

This rule defines how firmware changes should be planned, implemented and validated.

The primary goal is to keep changes understandable, testable and reversible.

## One Concern per Change

A development step SHOULD address one coherent concern.

Examples:

- add backup-battery monitoring
- refactor one display runtime
- clean up YAML comments
- update documentation
- fix one CAN protocol issue

Avoid combining unrelated functional changes into one commit.

## Preserve Known-Good Checkpoints

Large refactors SHOULD be split into independently working intermediate commits.

When a tested intermediate state is useful for debugging or rollback, commit it before continuing.

Do not unnecessarily collapse a sequence of meaningful, tested development steps into one large commit.

## Functional Changes vs. Cleanup

Functional changes and non-functional cleanup SHOULD be separated.

Functional changes include:

- entity changes
- timing changes
- control-flow changes
- hardware configuration changes
- CAN behavior changes
- display behavior changes
- safety behavior changes

Non-functional cleanup includes:

- comments
- README changes
- formatting
- documentation
- rule updates

During an explicitly non-functional cleanup, agents MUST NOT silently change runtime behavior.

If a functional defect is discovered, report it separately.

## Inspect Before Editing

Before modifying an existing subsystem, inspect its current implementation and relevant dependencies.

Do not assume that an earlier architecture or file location is still current.

For repository work, the current branch is the source of truth.

## Manual-Application Instructions

When an agent provides repository changes for a human to apply manually, the instructions MUST make the exact edit location unambiguous.

For each proposed change, provide:

- the exact repository file path
- an exact search anchor or existing block that identifies the edit location
- whether the new content must be inserted directly before or after that anchor, or whether the existing block must be replaced
- the complete replacement or resulting block whenever practical
- the complete file contents for a new small file when practical

Avoid vague instructions such as "add this to the file", "put this near the configuration" or "update the relevant section" when a precise location can be identified.

When several similar blocks exist in one file, the instructions MUST distinguish the intended occurrence clearly enough that the user does not have to infer which block is meant.

For repetitive edits, a systematic replacement rule MAY be used when it is less error-prone than repeating large nearly identical blocks. Any exceptions or manually different cases MUST be called out explicitly.

The goal is that a user applying a proposed change manually should not need to guess where content belongs or reconstruct the intended final structure from disconnected snippets.

## Reuse Existing Architecture

Prefer existing project abstractions and patterns over introducing parallel implementations.

Examples:

- use existing shared rectifier scripts
- use existing substitutions for project limits
- use existing page-specific display runtimes
- use existing CAN capability state

Do not duplicate logic merely because duplication is easier locally.

## Prefer Architectural Consistency Over Minimal Patches

When multiple implementation approaches are viable, prefer the one that preserves or improves a coherent project-wide architecture over the one that requires the least immediate code churn.

Agents MUST NOT introduce an isolated workaround, parallel mechanism or special-case implementation merely because it is faster or requires fewer edits when an established project pattern can be extended consistently.

Components that belong to the same functional family SHOULD follow the same structural pattern, ownership model, styling approach and state-management strategy unless there is a concrete technical reason to differ.

Examples include:

- dialogs and modal overlays
- page-specific display runtimes
- shared UI state
- aggregate telemetry
- charger-wide controls
- per-unit rectifier behavior
- hardware abstractions

A larger refactor is acceptable and SHOULD be preferred when it:

- restores architectural consistency
- removes competing implementation patterns
- reduces special-case logic
- improves maintainability
- makes future extensions simpler and more predictable

Before choosing a minimal local workaround, explicitly consider:

- whether an existing project pattern can be reused or generalized
- whether the proposed change would create two different ways to solve the same problem
- whether the solution would require future maintainers to remember a special case
- whether a somewhat larger refactor would produce a cleaner long-term design

If a deviation from the established architecture is genuinely necessary, the technical reason MUST be identified explicitly before proceeding.

## Keep Ownership Clear

Each piece of runtime behavior SHOULD have one obvious owner.

Examples:

- page layout -> `display/pages/`
- page runtime -> corresponding `display/*.yaml`
- persistent header runtime -> `display/header.yaml`
- shared command state -> `display/command-state.yaml`
- per-unit rectifier behavior -> parameterized rectifier package
- shared rectifier behavior -> shared rectifier package

When moving responsibility, update comments and documentation in the same change.

## Multi-Target Firmware Development

When the active firmware generation contains multiple targets, shared and target-specific responsibilities MUST remain explicit.

The target architecture is defined in:

```text
rules/firmware-targets.md
```

Shared code SHOULD contain behavior that is genuinely common to all participating targets.

Target-specific hardware access, telemetry acquisition and command transport SHOULD remain behind target-specific ownership boundaries.

A shared HMI implementation SHOULD depend on a target-neutral UI model rather than directly consuming controller-only or Remote-HMI-only transport entities.

When modifying shared UI or shared UI-model behavior, agents MUST inspect the effect on every active target that consumes that shared code.

Do not solve a target-specific problem by adding widespread target-condition checks throughout common code when a clean backend or composition boundary can preserve the shared architecture.

When a shared interface changes, update all affected target backends in the same coherent development step unless an explicitly planned intermediate compatibility layer is required.

## Validate Incrementally

After a meaningful structural change:

1. validate YAML / ESPHome configuration
2. compile
3. flash when hardware behavior is affected
4. verify the changed function
5. verify important adjacent functions
6. observe runtime stability when appropriate

For multi-target firmware, validation scope depends on ownership:

- shared UI or shared UI-model change -> validate and compile every consuming target
- Charger-Controller-specific change -> validate and compile the Charger Controller
- Remote-HMI-specific change -> validate and compile the Remote HMI
- shared target contract change -> validate and compile all affected targets

Before merging a release-level V6 change, both V6 targets MUST compile successfully.

A successful compile does not prove runtime correctness.

## Runtime Stability

Changes involving LVGL, ESP32 task execution, memory, CAN scheduling or frequent intervals SHOULD be tested for sustained runtime stability.

Do not treat a successful boot as sufficient evidence of stability.

When diagnosing intermittent failures, change one suspected cause at a time whenever practical.

## No Fake Runtime Data

Production UI and telemetry implementations MUST use real project entities.

Temporary fake values MAY be used only when explicitly requested for isolated UI prototyping and MUST NOT remain in production firmware.

## Safety-Critical Behavior

Existing safety limits, thermal protection, communication watchdogs and capability limits MUST NOT be weakened as a side effect of refactoring.

If a cleanup exposes questionable safety behavior, report it explicitly instead of silently redefining it.
