---
"@perfect-abstractions/compose-cli": patch
---

Fix `compose install` of catalog package facets (e.g. `ERC20DataFacet`) in Hardhat projects: package-sourced facets are never copied into `contracts/`, and Hardhat only compiles npm Solidity files listed in `solidity.npmFilesToBuild`, so the install-time validation compile missed the facet and failed with "Facet contract not found in Solidity AST". Install now adds the batch's package facets to the Compose `composeNpmFilesToBuild` overlay in `hardhat.config.ts` before validating, and reverts the config when the transaction rolls back. Projects whose config no longer contains the generated overlay get an error naming the exact specifiers to add manually. Foundry is unaffected (its validation compile already receives the facet paths directly). Install/remove error messages now carry recovery hints (`compose remove <facet>`, `path.sol:ContractName` examples, available diamond lists).
