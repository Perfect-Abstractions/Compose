# Deployment Script Generation

`DeployScriptPipeline.execute(ctx)` generates a deployment script from the selected diamond in `compose.json`. It is the generation workflow for the future `compose deploy` command, not an execution or confirmation workflow.

Inputs in `ctx.param`:

- `projectRoot`: search for `compose.json` here or in an ancestor directory.
- `diamond`: diamond key, required when several diamonds exist unless selected interactively.
- `chain`: chain key, defaults to `local`.
- `toolbox`: optional Hardhat `ethers` or `viem` override. Otherwise the framework adapter detects the installed deployment plugin.
- `yes`: disable interactive diamond selection.

The pipeline loads the selected local/package facets, runs `ValidatePipeline` in a scoped child context, checks compiled constructor signatures, and uses the shared deploy renderers. Validation includes the existing on-chain checks when `compose.lock` contains a deployment for the selected diamond. The parent retains the child result under `ctx.state.deployValidation`.

Scripts are written exclusively under `compose-scripts/<chain>/` with timestamped, unique filenames. Foundry imports are relative to the generated script. Hardhat contract references come from compiled artifacts, including package source names.

`ctx.state.deployScript` and `ctx.state.deployScriptPipeline` return a `DeployScriptArtifact`: script path, selected diamond, source and artifact contract identities, facet identities, chain, framework/toolbox, and source-AST expected selectors. Missing export evidence is represented as `null`. This artifact describes intended deployment and is not a transaction receipt or proof that runtime selectors match.

The generator does not change Solidity source, `compose.json`, or `compose.lock`, and does not broadcast transactions. Constructor initialization already in the diamond source is preserved and runs when the script is executed. Supported constructors take no arguments for facets and one `address[]` argument for the diamond. Other constructor shapes and explicit `init` configuration are rejected until their configuration schema is defined.
