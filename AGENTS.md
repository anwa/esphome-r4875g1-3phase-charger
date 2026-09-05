# Agent Instructions

Before modifying this repository, read and follow the applicable rules in `rules/`.

## Repository Language

All content that becomes part of this Git repository MUST be written in English.

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
- Git tags containing descriptive text
- user-visible strings added specifically as project documentation or   development metadata
- scripts and developer-facing log or error messages where new wording is added

Existing protocol-defined strings, external identifiers, entity IDs, hardware names and other values that must retain an established spelling are exempt.

Existing non-English content does not need to be translated merely because an unrelated file is edited. However, new or substantially rewritten repository content MUST be English.

When drafting repository content in a non-English conversation, agents MUST translate the final repository-facing text to English before proposing or committing it.

At minimum, review:

- `rules/README.md`
- `rules/development-workflow.md`
- `rules/git-workflow.md`

Depending on the task, also review:

- `rules/yaml-comments.md` for YAML changes
- `rules/documentation.md` for documentation changes
- `rules/versioning.md` for firmware changes and releases

Repository rules are normative for AI-assisted development unless the current task explicitly specifies otherwise.

When a change spans multiple areas, apply all relevant rule files.

Do not assume that rules remembered from an earlier session are current.
Always use the versions from the active Git branch.