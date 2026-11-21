# Local Validation

This rule defines how firmware configuration is validated and compiled on a local development machine before changes are committed or deployed.

## Tooling

The toolchain rules (pinned ESPHome version, `.venv`, `min_version`) are inherited from the workspace ESPHome rules. In this repository the ESPHome version is pinned in `requirements-dev.txt`, and both root configurations declare the matching `min_version`.

## Validation Script

Use the repository script:

```text
scripts/validate.ps1
```

Common invocations:

| Command | Purpose |
|---|---|
| `scripts/validate.ps1 -Setup` | create or update `.venv` and install the pinned tooling |
| `scripts/validate.ps1 -ConfigOnly` | run `esphome config` for both targets |
| `scripts/validate.ps1` | validate and compile both targets |
| `scripts/validate.ps1 -Target charger` | validate and compile only the Charger Controller |
| `scripts/validate.ps1 -Target hmi` | validate and compile only the Remote HMI |

The script returns a non-zero exit code when any selected target fails.

The first compile downloads the PlatformIO toolchain and can take several minutes.

## Validation Scope

The required target scope follows `rules/firmware-targets.md`:

- shared UI, shared UI-model or shared target-contract change -> both targets
- Charger-Controller-specific change -> Charger Controller
- Remote-HMI-specific change -> Remote HMI

Documentation-only and rule-only changes do not require compilation.

A functional change SHOULD pass at least `-ConfigOnly` before it is committed and SHOULD compile successfully for every affected target before it is offered for merge.

## Contract Check

`scripts/check-contract.py` checks the Controller's Home Assistant entities against every consumer listed in `AGENTS.md`:

- the integration role specifications (domain and original entity name)
- the contract version marker against the versions the integration supports
- the Grafana dashboard entity IDs
- the Remote HMI entity map
- the semantic roles referenced by the dashboard card

Run it from the repository root:

```text
.venv/Scripts/python.exe scripts/check-contract.py
```

The Controller inventory comes from the resolved `esphome config` output. The sibling repositories are expected next to this repository; missing ones are reported and skipped.

The contract check MUST pass before committing a change that adds, removes or renames a Controller entity, changes an entity domain or platform, or changes the contract version marker.

When a Grafana query intentionally uses a Home Assistant helper entity that the Controller does not provide, add it to `GRAFANA_EXTERNAL_OBJECT_IDS` in the script and document it in the dashboard repository.

The check proves that names and domains match. It does not check state formats. For example, a role whose domain changes from `binary_sensor` to `sensor` also changes its state values from `on`/`off` to numeric strings, and consumers that interpret the state must be reviewed manually.

## Secrets

The secret handling rules are inherited from the workspace ESPHome rules. `secrets.example.yaml` lists every secret referenced by both targets; `scripts/validate.ps1` creates `secrets.yaml` from it when the file is missing.

## Limits of Local Validation

A successful local compile proves that the configuration is buildable with the pinned ESPHome version, not that it works at runtime. Flashing, hardware tests and deployment through `scripts/deploy-ha.ps1` follow the inherited ESPHome rules and are done by the user.
