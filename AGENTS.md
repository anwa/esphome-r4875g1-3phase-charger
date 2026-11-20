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
- `rules/firmware-targets.md` for firmware architecture and target-specific changes

Depending on the task, also review:

- `rules/yaml-comments.md` for YAML changes
- `rules/documentation.md` for documentation changes
- `rules/versioning.md` for firmware changes and releases
- `rules/local-validation.md` for validating and compiling firmware locally

## Repository Access

### GitHub

GitHub access by AI agents is read-only by default.

Agents MUST NOT perform repository mutations through GitHub or a GitHub integration unless the user explicitly overrides this rule for the current task.

### Local Repository

Agents MAY edit files in the local working tree directly.

When the user asks for it, agents MAY create local branches and local commits.

Agents MUST NOT push, merge into `main` or a maintenance branch, create or move tags, create releases, or rewrite history that already exists on the remote. The user performs pushes, merges, tags and releases.

The complete policy is defined in:

```text
rules/git-workflow.md
```

## Related Repositories

This repository is one part of a project family. The sibling repositories are expected next to this one:

| Repository | Local path | Role |
|---|---|---|
| `esphome-r4875g1-3phase-charger` | `.` | Charger Controller and Remote HMI firmware; defines the Home Assistant entity contract in `HomeAssistant/ENTITY_CONTRACT.md` |
| `homeassistant-r4875g1-charger` | `../homeassistant-r4875g1-charger` | Home Assistant integration; resolves Controller entities into semantic roles and exposes the Backend API |
| `r4875g1-charger-dashboard` | `../r4875g1-charger-dashboard` | Home Assistant dashboard card and Grafana history dashboard; consumes the Backend API semantic roles |

### Contract Surfaces

`HomeAssistant/ENTITY_CONTRACT.md` is the authoritative description of the Controller entity contract.

The Controller's Home Assistant entities have several independent consumers. They do not all bind the same way:

| Consumer | Location | Binds by |
|---|---|---|
| Integration role resolution | `../homeassistant-r4875g1-charger/custom_components/r4875g1_charger/role_specs.py` | entity domain + original entity name (ESPHome `name:`) |
| Grafana history dashboard | `../r4875g1-charger-dashboard/grafana/dashboards/*.json` | Home Assistant entity ID in InfluxDB (`${instance}_<object_id>`), bypassing the integration |
| Remote HMI | `packages/remote-hmi/ha-entity-map.yaml` | Home Assistant entity ID derived from the configured Controller entity prefix |
| Dashboard card | `../r4875g1-charger-dashboard/src/api/` | Backend API v1 semantic roles, through the integration |

The contract version marker is a separate compatibility axis:

| Side | Location |
|---|---|
| Published by the Controller | `packages/controller/ha-contract.yaml` (`R4875G1 Charger Contract`) |
| Accepted by the integration | `SUPPORTED_CONTRACT_VERSIONS` in `../homeassistant-r4875g1-charger/custom_components/r4875g1_charger/const.py` |

### Cross-Repository Rules

- Changing an entity `name:`, entity domain or platform of a Controller entity is a contract change, even when firmware behavior is unchanged. Check every consumer in the table above in the same task, and run `scripts/check-contract.py` as described in `rules/local-validation.md`.
- Adding a Controller entity intended for Home Assistant consumers SHOULD update `ENTITY_CONTRACT.md` and, when it maps to a semantic role, the integration role specifications.
- An incompatible contract change requires a new contract version on both sides of the marker. Do not change one side alone.
- Backend API v1 changes in the integration must be checked against the dashboard API client and types.
- Each repository keeps its own versioning, changelog and validation rules. Apply the rules of the repository being changed.

The Charger Controller firmware remains authoritative for charger safety, CAN control, START eligibility and blackstart behavior in every repository.

## Rule Application

Repository rules are normative for AI-assisted development unless the current task explicitly specifies otherwise.

When a change spans multiple areas, apply all relevant rule files.

Do not assume that rules remembered from an earlier session are current.
Always use the versions from the active Git branch.
