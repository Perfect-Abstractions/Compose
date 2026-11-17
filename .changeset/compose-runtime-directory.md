---
"@perfect-abstractions/compose-cli": patch
---

Move every Compose-owned Hardhat runtime file into the ignored `.compose/hardhat/` directory (`.compose/foundry/` is reserved for Foundry): the transient Ignition runner, the generated deploy result, and the account probe. The probe is now a deterministic rendered template rather than a per-run `scripts/compose-account-check-<uuid>.ts` file, so an interrupted run can no longer leave an untracked script in a tracked directory. `compose init` and every runtime write now ensure the project `.gitignore` contains `.compose/`; the nested `cache/compose/.gitignore` workaround is gone.
