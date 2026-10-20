---
"@perfect-abstractions/compose-cli": patch
---

Resolve package facets from the project framework's package root (Foundry `lib/Compose`, Hardhat `node_modules`), so a project that has both copies no longer fails with an ambiguous package source.
