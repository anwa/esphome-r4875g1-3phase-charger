# Repository Rules

This directory contains the development and maintenance rules for this project.

The rules are primarily written for AI coding agents, but they are also intended to be readable and useful for human contributors.

## Purpose

These documents define repository-wide conventions that should remain stable across individual development sessions.

They exist to prevent architectural decisions, formatting conventions and release procedures from being rediscovered or inconsistently applied.

## Repository Language

English is the mandatory language for all repository content.

This applies to source comments, documentation, rules, commit messages, branch names, pull requests, release notes and other repository-facing text.

The conversation with an AI agent may use another language. Agents MUST translate repository-facing output to English before it is added to the repository.

Established identifiers, protocol-defined values, hardware names and external names are not subject to translation.

## Rules

| File | Purpose |
|---|---|
| `yaml-comments.md` | YAML comment hierarchy, formatting and documentation style |
| `development-workflow.md` | General rules for making and validating changes |
| `versioning.md` | Firmware versioning and version-bump policy |
| `documentation.md` | README and project-documentation maintenance |
| `git-workflow.md` | Branch, commit, merge and repository-history conventions |

## Precedence

When making changes:

1. explicit instructions for the current task take precedence
2. repository rules apply next
3. existing implementation patterns apply when no rule exists

Agents MUST NOT silently override an explicit current-task instruction because a repository rule recommends a different default.

## Scope

Rules describe how the current project should be maintained.

Historical implementation notes belong in Git history, release notes or other appropriate documentation rather than permanent source-code comments.

## Updating Rules

Rules are maintained like source code.

When a new recurring convention is established, consider documenting it here.

Rule changes SHOULD be committed separately from unrelated firmware changes when practical.

Changing a rule does not require a firmware version bump unless the same commit also changes firmware behavior.
