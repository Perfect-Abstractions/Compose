---
"@perfect-abstractions/compose-cli": minor
---

Add `compose deploy`: plan the diamond from `compose.json`, generate a reviewable managed framework script (its path is printed before interactive runs execute it), execute it through the framework (signing stays there), verify the result on-chain, and record the deployment in `compose.lock`. Supports `--chain`, `--instance`, `--broadcast`, `--dry-run`, `--redeploy`, and `--` passthrough for framework arguments.
