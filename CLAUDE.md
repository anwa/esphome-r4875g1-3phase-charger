@AGENTS.md

## Claude Code Notes

- The development machine runs Windows. Prefer PowerShell for repository scripts.
- Validate and compile firmware with `scripts/validate.ps1` as described in `rules/local-validation.md`. The first compile downloads the PlatformIO toolchain, so run it in the background.
- Run `.venv/Scripts/python.exe scripts/check-contract.py` after any change to Controller entities, integration role specifications, Grafana queries or the Remote HMI entity map.
- Edit files directly in the working tree. Create local branches and commits only when the user asks for them.
- Never push, merge into `main` or a maintenance branch, tag, release or run `scripts/deploy-ha.ps1`. The user does these steps.
- Commits made by Claude Code may end with a `Co-Authored-By` trailer.
- The sibling repositories listed in `AGENTS.md` are separate Git repositories with their own rules.
