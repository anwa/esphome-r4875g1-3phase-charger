# Git Workflow

This rule adds the repository-specific Git conventions. Git authority, branch naming, commit format and branch cleanup are defined by the inherited workspace rules.

## Long-Lived Branches

`main` contains the current primary firmware generation.

Maintained older firmware generations use dedicated long-lived maintenance branches:

```text
v5-maintenance
v4-maintenance
```

`v5-maintenance` contains the maintained V5 firmware generation and `v4-maintenance` the maintained V4 firmware generation.

Maintenance branches remain separate because firmware generations may target different hardware and architecture. They are never deleted during branch cleanup.

A new major firmware generation SHOULD normally be developed on a dedicated development branch, for example `feature/v6-dual-hmi-architecture`, before it replaces the primary generation on `main`. Once it does, the previous generation SHOULD remain available through its maintenance branch when continued maintenance is useful.

Relevant fixes made on the primary generation SHOULD be evaluated for backport to maintained older generations when the affected subsystem is shared. A fix MUST NOT be mechanically backported when architectural differences make the implementation inappropriate for the older generation.

## Merging

Before merging a development branch into `main`:

1. ensure the branch is based on an appropriate current base branch
2. verify the intended changes
3. validate and compile every firmware target affected by the change
4. state which hardware or runtime tests were performed and which are still open
5. confirm the firmware version
6. update required documentation
7. evaluate whether the change should be backported to maintained older generations

For shared V6 UI or shared target-contract changes, both V6 firmware targets MUST compile before merge.

A non-fast-forward merge MAY be used when preserving the identity of a feature branch is useful.

## Firmware Version in Commit Messages

A functional firmware commit SHOULD mention its resulting version in the subject, for example `fix: replace deprecated LVGL flag calls in v6.2.8`.

Documentation-only commits omit a firmware version because they do not create one.

## Release Tags

Create release tags only for firmware versions intended to be retained as release checkpoints, typically minor milestones, and only after the release state has been tested on the hardware sufficiently for its risk level. Patch versions are normally merged without a tag.

This repository publishes no GitHub releases.
