# Git Workflow

This rule defines the preferred Git workflow for the project.

The goals are readable history, safe experimentation and preservation of useful development context.

## Long-Lived Branches

`v5-maintenance` contains the maintained V5 firmware generation.

`v4-maintenance` contains the maintained V4 firmware generation.

`main` contains the current primary development line and may advance to newer firmware generations independently from the maintenance branches.

Maintenance branches preserve older firmware generations so fixes can be made without importing unrelated architectural changes from newer generations.

When working on `v5-maintenance`, the V5 branch is the source of truth for the V5 implementation.

Changes intended for V5 MUST be developed from an appropriate current `v5-maintenance` base and merged back into `v5-maintenance`, not into `main`.

Relevant fixes made on V5 SHOULD be evaluated for the current primary generation and other maintained generations when the affected subsystem is shared.

Likewise, fixes made on newer generations SHOULD be evaluated for V5 when the underlying defect also exists there.

Fixes MUST NOT be mechanically copied between generations when hardware, ownership, APIs or architecture differ.

## Feature and Refactor Branches

Meaningful development SHOULD normally happen on a dedicated branch.

Recommended naming:

```text
feature/<short-description>
fix/<short-description>
refactor/<short-description>
docs/<short-description>
```

Examples:

```text
feature/v5.3-battery-monitoring
refactor/v5-code-cleanup
fix/can-recovery
docs/readme-refresh
```

## Maintenance Development Branches

Meaningful V5 maintenance work SHOULD use a dedicated branch created from `v5-maintenance`.

Examples:

```text
fix/v5-can-recovery
fix/v5-display-state
docs/v5-maintenance-rules
```

A V5 maintenance branch SHOULD be merged back into `v5-maintenance` after validation.

Do not base V5 maintenance work on `main` merely because a newer implementation of the same subsystem exists there.

## Branch Lifetime

Temporary feature/refactor branches SHOULD be deleted after they have been fully merged and are no longer needed.

Deleting a fully merged branch does not remove commits or commit messages from the repository history.

Before deleting a branch, verify that it contains no commits that remain reachable only from that branch.

Long-lived maintenance branches are exempt.

## Commits

Commits SHOULD represent coherent, understandable development steps.

A commit message should state what changed, not merely that files changed.

Preferred subject style:

```text
Add controller backup battery monitoring
Refactor rectifiers runtime
Standardize top-level YAML documentation
Fix CAN recovery after bus-off
```

Use imperative or concise descriptive wording consistently.

All branch names, commit subjects and commit bodies MUST be written in English.

## Commit Bodies

For non-trivial changes, a commit body SHOULD summarize the important changes.

Example:

```text
Refactor persistent header runtime

- move persistent header updates out of ui.yaml
- reduce clock refresh frequency
- rename the header run-state widget
- keep battery updates in their dedicated runtime
```

Do not list every modified line.

## Firmware Version in Commit Messages

A functional firmware commit MAY mention its resulting version when useful.

Documentation-only commits SHOULD normally omit a firmware version from the subject because they do not create a new firmware version.

## Preserve Meaningful History

Do not rewrite or squash meaningful tested checkpoints merely to produce a shorter history.

Intermediate commits are valuable when they represent:

* a working milestone
* a debugging checkpoint
* an architectural transition
* an independently understandable change

## Merging

Before merging a V5 maintenance branch into `v5-maintenance`:

1. ensure the branch is based on an appropriate current `v5-maintenance`
2. verify the intended V5 changes
3. compile the final V5 firmware when firmware is affected
4. perform appropriate V5 hardware/runtime testing
5. confirm the V5 firmware version
6. update required V5 documentation
7. evaluate whether the same defect or improvement affects the current primary generation or another maintained generation

Forward-port and backport work SHOULD normally be performed as separate commits or branches so generation-specific changes remain reviewable.

A non-fast-forward merge MAY be used when preserving the identity of a maintenance branch is useful.

Pull-request titles, descriptions and repository-facing review summaries MUST be written in English.

## Release Tags

Create release tags only for firmware versions intended to be retained as release checkpoints.

Tag format:

`vMAJOR.MINOR.PATCH`

Do not create tags for documentation-only commits that retain an existing firmware version.

## Repository Cleanup

Periodically remove:

* fully merged temporary branches
* obsolete experimental branches
* stale documentation references

Do not delete a branch solely because it is old.

First verify whether it contains unique commits or serves as a maintained variant.
