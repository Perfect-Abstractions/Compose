---
"@perfect-abstractions/compose-cli": minor
---

Generated Foundry and Hardhat projects now include a preconfigured `sepolia` chain. `compose.json` points Sepolia at `${SEPOLIA_RPC_URL}`, Foundry projects add a `sepolia` entry under `[rpc_endpoints]`, and Hardhat projects define a Sepolia HTTP network that reads `SEPOLIA_RPC_URL` and the `SEPOLIA_PRIVATE_KEY` signer. Generated projects also include a `.env.example` and README instructions for Sepolia deployments.
