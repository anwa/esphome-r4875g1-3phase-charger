# Agent Instructions

## Inherited Rules

This repository lives in a rule hierarchy. Apply these files in addition to the rules below, in this order of increasing precedence:

| Level | File |
|---|---|
| Global | `../../../../AGENTS.md` |
| ESPHome | `../../../AGENTS.md` and `../../../rules/yaml-comments.md` |
| Waveshare | `../../AGENTS.md` |

They define language, Git authority, branches, commits, versioning principles, documentation style, the ESPHome toolchain, YAML comments and the Waveshare hardware and UI conventions. This file and `rules/` contain only what is specific to this repository; they take precedence over the inherited files.

If the inherited files are not present, for example in a fresh clone: write all repository content in English, never commit secrets, and never push, tag or publish without the user's approval.

## Repository Rules

Before modifying this repository, read and follow the applicable rules in `rules/`:

- `rules/README.md`
- `rules/development-workflow.md`
- `rules/git-workflow.md`
- `rules/firmware-targets.md` for firmware architecture and target-specific changes
- `rules/versioning.md` for firmware changes and releases
- `rules/documentation.md` for documentation changes
- `rules/local-validation.md` for validating and compiling firmware locally

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
