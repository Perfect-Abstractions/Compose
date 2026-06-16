# compose init

## Constraints

- For M1, `compose init` should primarily use modules. Adapters are not required for the normal `init` flow, but they may be introduced for reusable RPC-related validation work such as keccak or selector computation.
- Foundry and Hardhat are primary business concerns of the CLI, so their handling should be expressed explicitly through modules and pipelines.
- Adapters may be introduced later when a boundary needs flexibility, such as RPC clients or external-language integration.
- `compose.lock` may be mentioned for planning, but it is not implemented in M1.

## Modules

A module can contain multiple functions or methods.
Each function is a small unit of logic.

- A module can read everything from context.
- A module can mutate only its own section in context.

### entryModule

Handles user-facing CLI work and libraries such as `commander`, `inquirer`, and `picocolors`.

- Parse command input.
- Ask interactive questions when needed.
- Render terminal output.

### configModule

Handles config and metadata-related file work for M1.

- Read Compose-owned metadata from `bases`.
- Build generated `compose.json`.
- Write generated `compose.json` into the user project directory.

`compose.lock` is future scope and is not written by M1 `init`.

### pipelineBuilderModule

Determines which command was requested and routes to the correct pipeline.

### storageValidationModule

Contains the logic needed for storage collision checks.

- Reused from `validate`.
- May introduce an RPC-oriented adapter in M1 if that helps keep keccak-related logic reusable and isolated.

### selectorValidationModule

Contains the logic needed for selector collision checks.

- Reused from `validate`.
- May introduce an RPC-oriented adapter in M1 if that helps keep selector computation reusable and isolated.
- For Compose facets, `exportSelectors()` is the source used for cross-facet collision checking after per-facet completeness is verified.

### scaffoldingModule

Works with the filesystem and copies template files from Compose into the user's working directory.

## Pipelines

A pipeline should not implement business features directly.
It should call modules to do the business work.
A pipeline may use conditions, loops, and context parsing as part of orchestration.

Except for the command entrypoint, each pipeline takes context as input and returns context as output.

If a main pipeline calls a child pipeline:

- At the beginning, the child pipeline should take only the data it needs and create a separate child context.
- The main pipeline can read the child pipeline result and append it back into the main context.

### entryPipeline.ts

Root pipeline for command execution.

- Call `entryModule` to handle CLI-facing work.
- Determine which mode to use.
- Determine which framework to use.
- Route the request to the correct pipeline.

### foundryInitPipeline

Handles the `init` command for Foundry.

### hardhatInitPipeline

Handles the `init` command for Hardhat.

### storageValidatePipeline

Reused from `validate`.

### selectorValidatePipeline

Reused from `validate`.

### scaffoldingPipeline

Handles file-copy orchestration by calling `scaffoldingModule`.

If a filesystem exception occurs during scaffolding, the pipeline should support rollback behavior.
