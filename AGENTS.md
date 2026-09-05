# Agent Instructions

Before modifying this repository, read and follow the applicable rules in `rules/`.

## Repository Language

All human-readable repository content created or substantially modified in this project MUST be written in English.

This requirement applies regardless of the language used in the conversation with the user. The normal conversation language may be German, but repository content must remain English.

This includes, but is not limited to:

- source-code comments
- YAML comments
- Markdown documentation
- README files
- repository rules
- commit messages
- branch names
- pull-request titles and descriptions
- release notes
- developer-facing script output
- developer-facing log and error messages
- other human-readable project text

The language rule does not require translation of protocol-defined strings, external identifiers, entity IDs, hardware or product names, file-format keywords, API-defined values, or other text whose spelling is externally fixed.

Existing non-English content does not need to be translated merely because an unrelated file is edited. However, new or substantially rewritten repository-facing text MUST be English.

When drafting repository content in a non-English conversation, agents MUST translate the final repository-facing text to English before proposing or committing it.

## Required Rules

At minimum, review:

- `rules/README.md`
- `rules/development-workflow.md`
- `rules/git-workflow.md`

Depending on the task, also review:

- `rules/yaml-comments.md` for YAML changes
- `rules/documentation.md` for documentation changes
- `rules/versioning.md` for firmware changes and releases

## Rule Application

Repository rules are normative for AI-assisted development unless the current task explicitly specifies otherwise.

When a change spans multiple areas, apply all relevant rule files.

Do not assume that rules remembered from an earlier session are current.
Always use the versions from the active Git branch.
