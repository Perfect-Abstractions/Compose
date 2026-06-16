# Compose CLI - Internal Architecture Proposal

> **Status:** Draft  
> **Date:** 2026-05-20  
> **Product:** Compose CLI  
> **Version:** 0.1.0  

---

## Table of Contents

1. [Pipeline-Oriented Modular Architecture](#pipeline-oriented-modular-architecture)
2. [Assumptions / Constraints](#assumptions--constraints)
3. [General](#general)
4. [Context Object (`ctx`)](#context-object-ctx)
   - [Example Context Types](#example-context-types)
   - [Example Context Values](#example-context-values)
   - [Notes](#notes)
5. [Pipeline](#pipeline)
   - [Main Pipeline](#main-pipeline)
   - [Child Pipeline](#child-pipeline)
   - [Child Pipeline and Concurrency](#child-pipeline-and-concurrency)
   - [Example](#example)
   - [Note](#note)
6. [Modules](#modules)
   - [Modules Example](#modules-example)
   - [Note](#note-1)
7. [Module, Pipeline, and Adapters](#module-pipeline-and-adapters)
8. [Adapters](#adapters)
   - [Adapter example](#adapter-example)
   - [Modules and Adapters](#modules-and-adapters)
9. [Dependency Resolver and Registry](#dependency-resolver-and-registry)
   - [Example](#example-1)
10. [Utils](#utils)
    - [Utils Workflow](#utils-workflow)
11. [Change Log](#change-log)

---

## **Pipeline-Oriented Modular Architecture**

A modular architecture where pipelines own orchestration, modules provide stateless units of work, and adapters isolate external tools and libraries.

## Assumptions / Constraints

- The CLI is a one-shot tool, not a daemon or background service.

- The CLI will evolve across multiple milestones, so the architecture should tolerate new features and breaking changes.

- The CLI remains a Node.js tool, consistent with the current tech stack.

- The CLI never holds, stores, or transmits private keys.

- This architecture should respect the constraints defined in the original PRD.

## General

![Pipeline-Oriented Modular Architecture](./resources/pipeline-oriented-modular-architecture.png)

This architecture is built around four main components: **Context (`ctx`)** , **Pipeline**, **Module**, and **Adapter**.

- Pipelines define sequential chains of actions for specific workflows.

- Context carries shared state throughout a pipeline execution.

- Modules are focused units of work that handle the business logic of each step.

- Adapters are focused units of work that handle external tools, external libraries, or runtime-specific concerns. 

Each command input is parsed into a context object, then passed into the corresponding pipeline. 

The pipeline calls modules in order to process the workflow. If a module needs to interact with an external tool, library, API, or runtime, it calls an adapter. 

The same context is passed from the first module to the last module in the pipeline.

## Context Object (`ctx`)

The context object represents the execution scenario of a single command. It centralizes shared information so that modules executed later in the pipeline have the data they need to complete their work.

The context object can contain parameters, config, module state, child pipeline state, and errors produced during execution. However, it should not own execution behavior. Its role is to carry information between modules and child pipelines through a controlled shared structure, instead of making them depend on each other directly.

### Example Context Types

```ts

type ComposeError = {
  code: string;
  message: string;
  nativeError: unknown | null;
};

type ModuleState<T = unknown> = {
  success: boolean;
  result: T | null;
  error: ComposeError | null;
};

type ExecutionStatus = {
  success: boolean;
  stopped: boolean;
  failedAt: string | null;
  error: ComposeError | null;
};

type ChildPipelineState = {
  success: boolean;
  state: Record<string, ModuleState>;
  status: ExecutionStatus;
};

type ComposeContext = {
  param: Record<string, unknown>;
  config: Record<string, unknown>;
  state: Record<string, ModuleState | ChildPipelineState>;
  status: ExecutionStatus;
};

```

### Example Context Values

```ts 

const ctx: ComposeContext = {
  param: {
    // Parsed command input from the command entrypoint.
  },

  config: {
    // Loaded config and long-lived project data,
    // such as compose.json, compose.lock, and project metadata.
  },

  state: {
    fileSystem: {
      success: true,
      result: {
        // File System Module output.
      },
      error: null,
    },

    validationPipeline: {
      success: false,

      state: {
        validateIdentifier: {
          success: true,
          result: {
            // Identifier validation output.
          },
          error: null,
        },

        validateLayout: {
          success: false,
          result: null,
          error: {
            code: "LAYOUT_VALIDATION_FAILED",
            message: "Layout validation failed.",
            nativeError: null,
          },
        },
      },

      status: {
        success: false,
        stopped: true,
        failedAt: "validationPipeline.validateLayout",

        error: {
          code: "VALIDATION_PIPELINE_FAILED",
          message: "Validation pipeline failed.",
          nativeError: null,
        },
      },
    },

    // ...
    // more modules / child pipelines here
  },

  status: {
    // Top-level command execution status.

    success: false,
    stopped: true,
    failedAt: "validationPipeline.validateLayout",

    error: {
      code: "COMMAND_FAILED",
      message: "Command execution failed.",
      nativeError: null,
    },
  },
};

```

### Notes

- Context allows modules to be added, removed, or reordered across different stages of a pipeline with fewer direct dependencies between modules.

- It gives modules executed later in the pipeline access to the information produced by previous steps, which enables fallback scenarios when something does not work as expected.

- In a development environment, it can also provide a full trace of the workflow, which is valuable for debugging.

## Pipeline

In this architecture, a pipeline acts as an orchestrator.
It defines what the workflow looks like, which modules should be called, and the order in which they should run.

A pipeline should only coordinate module execution. It should not execute business logic directly, and it should not interact with adapters by itself. If external interaction is needed, the pipeline calls a module, and the module calls the adapter.

### Main Pipeline

![Main-Pipeline](./resources/main-pipeline.png)

A Main Pipeline is the primary workflow of a CLI command.

Each command, such as init, validate, diff, or plan, creates a context object and passes it into one Main Pipeline from its command entrypoint. From there, the Main Pipeline orchestrates the modules required to complete the command.

The Main Pipeline does not need to be directly aware of the command implementation. It only receives a context object and executes the workflow defined for that pipeline.

### Child Pipeline

At some stages of a pipeline, there may be multiple smaller modules that need to run as a group. In that case, a pipeline can call another pipeline as part of its workflow. This inner pipeline is called a Child Pipeline.

![Child-Pipeline](./resources/child-pipeline.png)

Each Child Pipeline should create its own context object from the parent context, containing only the information required for that pipeline to run.

After the Child Pipeline finishes, it returns its result. The parent pipeline then appends the Child Pipeline context or result into the state of its own context, and continues to the next action.

This keeps the Child Pipeline isolated while still allowing the parent pipeline to collect its output in a controlled way.

### Child Pipeline and Concurrency

A Child Pipeline is particularly useful for managing concurrency.  
Each Child Pipeline reads from and writes to its own context object, while keeping the workflow of its internal modules consistent and predictable.

A useful benefit of this model is that concurrency is handled at the Child Pipeline boundary. The parent pipeline only sees the Child Pipeline as one executable unit, while the Child Pipeline keeps its internal module workflow predictable.

When the workflow needs to evolve, developers can add more modules inside the Child Pipeline and arrange their order normally, without manually managing parallel execution, thread locks, or shared-state coordination for each individual module.

Parallel Child Pipelines should be executed with a reasonable concurrency limit, so the CLI can improve performance without overwhelming the local machine or RPC provider.

### Example

**Main Pipeline**

```ts

async function mainPipeline(ctx: ComposeContext): Promise<ComposeContext> {
  // Run normal modules in the parent pipeline.
  ctx = await FileSystem.load(ctx);

  // Execute the child pipeline with an isolated child context.
  const validationCtx: ComposeContext = await ValidationPipeline.execute(ctx);

  // Append the child pipeline result back into the parent context state.
  ctx.state.validationPipeline = {
    success: validationCtx.status.success,
    state: validationCtx.state,
    status: validationCtx.status,
  };

  // Continue the parent pipeline after collecting the child pipeline output.
  ctx = await Output.write(ctx);

  return ctx;
}

```

**Child Pipeline**

```ts

const ValidationPipeline = {
  async execute(parentCtx: ComposeContext): Promise<ComposeContext> {
    const fileSystemState = parentCtx.state.fileSystem as ModuleState<{
      identifiers: unknown;
      layout: unknown;
    }>;

    // Create an isolated context for this child pipeline.
    // Only pass the data this pipeline needs from the parent context.
    let childCtx: ComposeContext = Context.createChild(parentCtx, {
      name: "validationPipeline",
      input: {
        identifiers: fileSystemState.result?.identifiers,
        layout: fileSystemState.result?.layout,
      },
    });

    // Run actions from the Validation module in a predictable order.
    childCtx = await Validation.computeKeccak(childCtx);
    childCtx = await Validation.validateIdentifier(childCtx);
    childCtx = await Validation.validateLayout(childCtx);

    // Finalize the child pipeline status before returning it to the parent.
    childCtx.status = {
      success: true,
      stopped: false,
      failedAt: null,
      error: null,
    };

    // Return the child context to the parent pipeline.
    // The parent pipeline can append this result into its own context state.
    return childCtx;
  },
};

```

### Note

- While powerful, Child Pipelines should not be overused. Too many nested pipelines can make the workflow branch too much and increase unnecessary complexity.

- The Main Pipeline can call Modules directly or call a Child Pipeline when a group of actions needs isolation, concurrency, or room to grow.

- Child Pipelines should not be nested further unless there is a very strong reason, because deep nesting makes the workflow harder to follow.

**For Compose CLI, I recommend keeping the structure to one Main Pipeline and at most one level of Child Pipeline.**

## Modules

A Module is a focused group of units of work inside a pipeline.  
It represents a group of related functions that solve one business concern.  

Each function inside a module should do one focused task. It can read the context, perform its work, and write its own result back into the context.  

A module function should not modify state owned by another module. If it needs data from another module, it should read that data from the context instead of depending on that module directly.  

### Modules Example

```ts

const Validation = {
  async computeKeccak(ctx: ComposeContext): Promise<ComposeContext> {
    // Compute keccak-based identifiers.
    // Write result to ctx.state.computeKeccak.
    return ctx;
  },

  async validateIdentifier(ctx: ComposeContext): Promise<ComposeContext> {
    // Validate identifier rules.
    // Write result to ctx.state.validateIdentifier.
    return ctx;
  },

  async validateLayout(ctx: ComposeContext): Promise<ComposeContext> {
    // Validate layout rules.
    // Write result to ctx.state.validateLayout.
    return ctx;
  },
};

```

### Note

Module functions follow a functional-style interface. **They receive a context object and return the context object**. However, for a CLI tool, recreating the whole context object on every module call may create unnecessary memory overhead, especially when the context contains artifacts, layouts, bytecode, or reports. Because of that, modules are allowed to append their own execution result into the context. This is a more practical and efficient approach, as long as each module only writes to its own state section.

Grouping module functions by semantic meaning also creates a clear anchor for reading the source code. A new developer can quickly understand which modules a pipeline uses, then go deeper into a specific pipeline or module when needed. This improves readability for humans and also provides better context anchors for AI-assisted development.

## Module, Pipeline, and Adapters

Some modules may need to interact with external tools, libraries, APIs, or runtimes. These interactions should be handled through adapters.

To reduce the cost of future changes, modules should not declare or create adapters directly. Instead, the required dependencies should be resolved by the pipeline and passed into the module from the beginning.

A module function can receive dependencies through its signature, for example:

```ts

Module.function(ctx, deps)

```

The pipeline is the orchestration layer. It knows which modules and adapters are needed for its business flow, so it is the practical place to select and assign adapters explicitly.

This makes sense because the pipeline does not directly perform adapter operations or internal business logic. It simply coordinates the correct adapter with the correct module.

```ts

interface HashingAdapterInterface {
  keccak256(value: string): string;
}

type SelectorCollisionDeps = {
  hashing: HashingAdapterInterface;
};

// Create adapters from registry.
const deps = (await DependencyResolver.resolve([
  {
    key: DependencyKey.Hashing,
  },
])) as SelectorCollisionDeps;

// Assign adapters to module.
ctx = await ValidationModule.detectSelectorCollisions(ctx, {
  hashing: deps.hashing,
});

```

This keeps modules stateless and testable, while allowing pipelines to control adapter lifecycle and dependency scope.  
The dependency resolver and adapter conventions will be described in later sections.

## Adapters

![Adapters](./resources/adapters.png)

In traditional software design, an adapter is a pattern used to interact with external dependencies through a stable interface.

The idea is simple: modules should call a stable adapter interface instead of depending directly on a specific library. If we later need to replace a library, we can update the registry and implement a new adapter while keeping most modules and pipelines unchanged.

This is especially important for Web3 tooling, where libraries and frameworks can change quickly. If Compose CLI wants to keep up with new tooling trends, adapters can become an important leverage point.

**For Compose CLI, adapters can also provide another benefit. They can help the Node.js layer communicate with external systems or extensions cleanly.**

Some performance-sensitive or security-sensitive features could be implemented outside the Node.js layer, for example in Rust or C++. In that case, the adapter becomes the communication boundary between the Node.js orchestration layer and the external implementation.

The Node.js pipeline and modules can still orchestrate the workflow, while adapters handle the integration details.

If the CLI later needs to rewrite part of the core, the new core can reuse these extensions naturally as long as the adapter boundary remains stable and well-defined.

### Adapter example

A `DiamondInspectAdapter` can be used to read Diamond introspection data without coupling modules directly to a specific RPC library.

The adapter exposes an interface:

```ts

interface DiamondInspectAdapter {
  facetAddresses(address: string): Promise<string[]>;
}

```

The implementation can use `viem`, `ethers.js`, or another RPC library internally:

```ts

class ViemDiamondInspectAdapter implements DiamondInspectAdapter {
  constructor(private readonly client: ViemClient) {}

  async facetAddresses(address: string): Promise<string[]> {
    const result = await this.client.readContract({
      address: address as `0x${string}`,
      abi: IDiamondInspectAbi,
      functionName: "facetAddresses",
    });

    return [...result].map(String);
  }
}

```

The module only depends on the interface:

```ts

type DiamondInspectDeps = {
  diamondInspect: DiamondInspectAdapter;
};

const DiamondInspect = {
  async readFacetAddresses(
    ctx: ComposeContext,
    { diamondInspect }: DiamondInspectDeps
  ): Promise<ComposeContext> {
    const facetAddresses = await diamondInspect.facetAddresses(
      ctx.param.address as string
    );

    ctx.state.diamondInspect = {
      success: true,
      result: {
        facetAddresses,
      },
      error: null,
    };

    return ctx;
  },
};

```

The pipeline asks the dependency resolver to create the adapter from the registry, then passes the resolved dependency into the module:

```ts

const chain = ctx.config.chains[ctx.param.chain];

const deps = (await DependencyResolver.resolve([
  {
    key: DependencyKey.DiamondInspect,
    params: {
      rpcUrl: chain.rpc,
      chainId: chain.chainId,
    },
  },
])) as DiamondInspectDeps;

ctx = await DiamondInspect.readFacetAddresses(ctx, deps);

```

If Compose later switches from `viem` to `ethers.js`, only the `ViemDiamondInspectAdapter` implementation needs to change.

### Modules and Adapters

Modules and adapters have a special relationship. Both are grouped units of work that help handle a real feature or concern.

- A module handles internal data and business logic.  

- An adapter handles communication with the external world.

Together, they allow the CLI to implement a feature without coupling the internal logic directly to external libraries, tools, APIs, or runtimes.

However, this boundary needs to be balanced carefully.

If an adapter contains too much business logic, such as validating domain input or enforcing feature-specific output constraints, it can become too specific to one module and hard to reuse elsewhere.

On the other hand, if an adapter is too thin and only mirrors the external library API, then many modules can use it, but replacing the underlying library may still force changes across the codebase. In that case, the adapter loses part of its value.

A balanced approach is to split responsibilities by feature:

- The module owns the feature logic and validation.

- The adapter owns the external communication and library-specific details.

This gives us a clean boundary without turning adapters into hidden business modules.

Adapters and interfaces are powerful concepts, but overusing them can create a lot of unnecessary code. So they should be used mainly for features that need flexibility or may change over time, such as RPC clients or external extensions.

For stable dependencies that are unlikely to change often, such as basic CLI parsing or filesystem access, it may be more practical to use a simple module/ utils and accept some coupling.

## Dependency Resolver and Registry

The dependency resolver is a special module that provides a lightweight mechanism for resolving adapter dependencies at the pipeline level.

It is similar to dependency injection in the sense that dependencies are still defined explicitly in one place. However, instead of letting a container construct and inject dependencies automatically, the pipeline resolves the adapter dependencies it needs at the stage where they are needed and passes them into modules explicitly.

This concept is useful for a CLI because it gives us the convenience of separating adapter definitions from the main workflow, while avoiding the burden of loading or constructing every dependency upfront.

![Resolver](./resources/resolver.png)

- The Registry is the single source of truth for mapping dependency keys to adapter factories.

- Resolver creates adapters from explicit dependency requests.

- Pipeline decides which adapter dependencies are needed for each stage.

- Module receives the resolved adapters through its function signature.

### Example 

Registry Example

```ts

// Dependency keys are also used as output field names in the resolved deps object.
enum DependencyKey {
  DiamondInspect = "diamondInspect",
}

type DependencyParams = Record<string, unknown>;

type DependencyFactory<T = unknown> = (
  params?: DependencyParams
) => Promise<T> | T;

type DependencyRequest = {
  key: DependencyKey;
  params?: DependencyParams;
};

// Registry maps dependency keys to adapter factories.
const DependencyRegistry: Record<DependencyKey, DependencyFactory> = {
  [DependencyKey.DiamondInspect]: (params) => {
    const rpcUrl = params?.rpcUrl as string;
    const chainId = params?.chainId as number;

    const client = createViemClient({
      rpcUrl,
      chainId,
    });

    return new ViemDiamondInspectAdapter(client);
  },
};

```

Dependency Resolver Example

```ts 

const DependencyResolver = {
  async resolve(
    requests: DependencyRequest[]
  ): Promise<Record<string, unknown>> {
    // Resolved dependencies are returned as an object keyed by DependencyKey values.
    const deps: Record<string, unknown> = {};

    for (const request of requests) {
      const factory = DependencyRegistry[request.key];

      if (!factory) {
        throw new Error(`Dependency factory not found: ${request.key}`);
      }

      // Create the adapter only when the pipeline explicitly requests it.
      deps[request.key] = await factory(request.params);
    }

    return deps;
  },
};

```

## Utils

Utils are shared mechanical helpers.

They are not a workflow component. They are a supporting source layer for small reusable operations that do not carry Compose business meaning.

```txt
src/
  utils/
    files.ts
    regex.ts
    ...
```

Examples:

- file helpers
- regex helpers
- string normalization helpers
- generic JSON helpers
- small path helpers

Do not put Compose domain logic in utils.

A util should not depend on:

- `ComposeContext`
- `BasesCatalog`
- `FacetEntry`
- module state
- pipelines
- adapters
- resolver

If a helper understands selected facets, bases, selector ownership, storage layout rules, scaffold categories, or validation rules, it belongs in a module instead of utils.

### Utils Workflow

Before adding a new helper:

1. Check the existing `src/utils` directory.
2. Reuse an existing util if it already solves the problem.
3. If a close category exists, append the helper to that util file.
4. If no close category exists, create a small new util category.
5. Do not rewrite, delete, or change existing util behavior unless the task is explicitly utility maintenance.

Main rule:

```txt
Utils handle mechanics.
Modules handle meaning.
```

## Change Log

| Date | Change | Rationale |
|---|---|---|
| 2026-06-16 | Added `Utils` as a supporting source layer. | AI usually creates small helpers for utility logic, which can add duplicate or fragmented helper functions across module files. The utils layer defines a mechanism to organize utility logic effectively without dumping everything into one object or scattering fragmented functions across the codebase. |
