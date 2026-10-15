---
"@perfect-abstractions/compose-cli": patch
---

Accept `path.sol:ContractName` references in `compose remove`/`rm` and remove manifests, so they resolve to the registered facet name the way `compose install` does instead of being skipped as unregistered.
