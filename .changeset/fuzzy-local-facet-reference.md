---
"@perfect-abstractions/compose-cli": patch
---

Resolve bare facet names in `compose install` by fuzzy-matching the project's Solidity sources, so a local `path.sol:ContractName` reference is only needed when several sources match; interactive runs pick the source from a list.
