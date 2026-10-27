---
"@perfect-abstractions/compose-cli": minor
---

Add `compose deploy`: plan the diamond from `compose.json` and generate a reviewable managed deployment artifact. Foundry uses a Solidity script; Hardhat 3 uses a Hardhat Ignition module with an ignored transient runner. The default command prints the artifact path and review instructions without prompting or broadcasting; `--dry-run` simulates on a pinned chain fork, while `--broadcast` explicitly deploys, verifies the result on-chain, and records it in `compose.lock`. Hardhat deployment transaction hashes are read from the Ignition journal by future ID. Signing stays in the framework. Supports `--chain`, a per-deployment `--rpc-url` override, named Compose account aliases, `--instance`, `--redeploy`, and `--` passthrough for framework arguments. Add and list non-secret account aliases with `compose account`.

Hardhat 3 initialization now uses Hardhat's official non-interactive Ethers/Mocha or Viem/Node test-runner template, overlays Compose project settings without discarding the official config, and requires Node.js 22.13 or newer.
