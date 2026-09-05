# Git Workflow

This rule defines the preferred Git workflow for the project.

The goals are readable history, safe experimentation and preservation of useful development context.

## Long-Lived Branches

`main` contains the current V5 firmware.

`v4-maintenance` is a long-lived maintenance branch for the V4 hardware variant.

V4 remains separate because it targets different hardware.

Relevant shared fixes, especially CAN protocol fixes, MAY be backported from V5 to `v4-maintenance` when appropriate.

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

Before merging a development branch into `main`:

1. ensure the branch is based on an appropriate current `main`
2. verify intended changes
3. compile the final firmware when firmware is affected
4. perform appropriate hardware/runtime testing
5. confirm the firmware version
6. update required documentation

A non-fast-forward merge MAY be used when preserving the identity of a feature branch is useful.

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
