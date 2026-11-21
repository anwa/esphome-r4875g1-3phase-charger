@AGENTS.md

## Claude Code Notes

- Validate and compile firmware with `scripts/validate.ps1` as described in `rules/local-validation.md`.
- Run `.venv/Scripts/python.exe scripts/check-contract.py` after any change to Controller entities, integration role specifications, Grafana queries or the Remote HMI entity map.
- The sibling repositories listed in `AGENTS.md` are separate Git repositories with their own rules.
