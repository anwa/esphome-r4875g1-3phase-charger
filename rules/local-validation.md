# Local Validation

This rule defines how firmware configuration is validated and compiled on a local development machine before changes are committed or deployed.

## Tooling

Local validation uses ESPHome in a project-local Python virtual environment.

The ESPHome version is pinned in:

```text
requirements-dev.txt
```

The pinned version SHOULD match the ESPHome version used by the Home Assistant ESPHome add-on that builds the deployed firmware.

The pinned version MUST satisfy the `min_version` declared in the root configurations.

The virtual environment is created in `.venv/` and MUST NOT be committed.

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

## Secrets

The real `secrets.yaml` is never committed.

`secrets.example.yaml` contains dummy values for every secret referenced by the configurations. When `secrets.yaml` is missing, the validation script creates it from the example file and prints a warning.

Agents MUST NOT write real credentials into `secrets.yaml`, `secrets.example.yaml` or any other repository file.

When a configuration references a new secret, add a dummy entry to `secrets.example.yaml` in the same change.

## Limits of Local Validation

A successful local compile proves that the configuration is buildable with the pinned ESPHome version. It does not prove runtime correctness.

Flashing, hardware tests and runtime-stability observation remain required where `rules/development-workflow.md` asks for them. They are performed by the user unless the current task explicitly says otherwise.

Deployment to Home Assistant through `scripts/deploy-ha.ps1` is performed by the user.
