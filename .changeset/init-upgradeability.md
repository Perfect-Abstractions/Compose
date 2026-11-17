---
"@perfect-abstractions/compose-cli": minor
---

Scaffold immutable diamonds by default: `compose init` prompts for upgradeability, defaulting to Immutable, and non-interactive runs accept `--upgradeable` and `--immutable`. `--upgradeable` includes `DiamondUpgradeFacet` and couples the `owner` base when no ownership base is selected; an explicit `DiamondUpgradeFacet` in `--libraries` opts in for compatibility. Hardhat projects also scaffold a `local` network entry targeting the default Anvil RPC.
