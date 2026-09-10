# Git Workflow

This rule defines the preferred Git workflow for the project.

The goals are readable history, safe experimentation and preservation of useful development context.

## GitHub Access Policy

AI agents MUST treat the GitHub repository and all GitHub integrations as read-only.

Agents MAY:

- inspect repositories, branches, commits, tags and files
- inspect pull requests, issues, workflow results and repository history
- compare remote repository state with user-provided local changes
- review commits, diffs and pull requests
- prepare patches and complete replacement files for local application
- prepare commit messages, branch names, pull-request text and merge recommendations

Agents MUST NOT perform repository mutations through GitHub or a GitHub integration.

Prohibited actions include, but are not limited to:

- creating, updating or deleting repository files
- creating commits
- creating, deleting or modifying branches
- moving branch references
- pushing changes
- merging pull requests
- creating, updating or deleting tags
- creating, updating or deleting releases
- modifying issues or pull requests
- changing repository settings
- performing any other GitHub API action that changes repository or project state

Repository changes MUST first be applied to the user's local working tree.

When an agent prepares a change, it SHOULD provide either:

- an exact patch that can be applied locally, or
- precise manual-application instructions following `rules/development-workflow.md`

The user is responsible for:

- applying the final change to the local repository
- validating and compiling affected firmware targets
- performing required hardware or runtime tests
- creating Git commits
- pushing commits to GitHub
- performing merges, tags and releases

Agents MAY inspect the resulting pushed commit afterwards to verify that it matches the intended and tested change.

This policy applies even when the available GitHub integration technically provides write-capable tools.

A write operation is permitted only when the user explicitly overrides this repository rule for the current task.

## Long-Lived Branches

`main` contains the current primary firmware generation.

Maintained older firmware generations use dedicated long-lived maintenance branches.

Current maintenance branches are:

```text
v5-maintenance
v4-maintenance
```

`v5-maintenance` contains the maintained V5 firmware generation.

`v4-maintenance` contains the maintained V4 firmware generation.

Maintenance branches remain separate because firmware generations may target different hardware and architecture.

A new major firmware generation SHOULD normally be developed on a dedicated development branch before it replaces the primary generation on `main`.

For example:

```text
feature/v6-dual-hmi-architecture
```

Once a new generation becomes the primary implementation on `main`, the previous generation SHOULD remain available through its maintenance branch when continued maintenance is useful.

Relevant fixes made on the primary generation SHOULD be evaluated for backport to maintained older generations when the affected subsystem is shared.

A fix MUST NOT be mechanically backported when architectural differences make the implementation inappropriate for the older generation.

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

1. ensure the branch is based on an appropriate current base branch
2. verify intended changes
3. validate every firmware target affected by the change
4. compile every required firmware target
5. perform appropriate hardware/runtime testing
6. confirm the firmware version
7. update required documentation
8. evaluate whether the change should be backported to maintained older generations

For shared V6 UI or shared target-contract changes, both V6 firmware targets MUST compile before merge.

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
