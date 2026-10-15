---
"@perfect-abstractions/compose-cli": patch
---

Preserve the relative folder structure of locally imported dependencies when copying catalog facets, so nested imports (for example `./libraries/LibFee.sol`) keep resolving after `compose install` and `compose init`.
