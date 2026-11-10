---
"@perfect-abstractions/compose-cli": patch
---

`compose init` now adds `@perfect-abstractions/compose-cli` to the generated project's `devDependencies` and installs it, so Compose commands run locally with `npx compose` without a global install. Foundry projects now include a `package.json` for this, and the tutorial and generated READMEs use the `npx compose` flow.
