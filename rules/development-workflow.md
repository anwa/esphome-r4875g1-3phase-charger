# Development Workflow

This rule defines how firmware changes should be planned, implemented andvalidated.

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

## Reuse Existing Architecture

Prefer existing project abstractions and patterns over introducing parallel implementations.

Examples:

- use existing shared rectifier scripts
- use existing substitutions for project limits
- use existing page-specific display runtimes
- use existing CAN capability state

Do not duplicate logic merely because duplication is easier locally.

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

## Validate Incrementally

After a meaningful structural change:

1. validate YAML / ESPHome configuration
2. compile
3. flash when hardware behavior is affected
4. verify the changed function
5. verify important adjacent functions
6. observe runtime stability when appropriate

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
