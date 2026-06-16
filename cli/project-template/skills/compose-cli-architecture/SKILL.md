---
name: compose-cli-architecture
description: Generate Compose CLI code, design workflows, review boundaries, or refactor using the pipeline-oriented modular architecture. Use for commands, context, pipelines, child pipelines, modules, adapters, dependency resolver, registry, and boundary decisions.
---

# Compose CLI Architecture

## Core idea

Compose CLI is a one-shot Node.js CLI.

Use this architecture:

```txt
Command parses input.
Context carries execution state.
Pipeline orchestrates workflow.
Module owns feature logic.
Adapter talks to external systems.
Resolver creates requested dependencies.
Registry maps dependency keys to factories.
```

## Use this skill when

- Designing a command workflow.
- Generating pipeline/module/adapter code.
- Reviewing architecture boundaries.
- Deciding where logic belongs.
- Refactoring external library usage behind adapters.
- Adding dependency resolver or registry entries.

## Do not use this skill for

- Generic TypeScript help.
- Generic Node.js CLI setup.
- UI/frontend code.
- Long-running service or daemon architecture.
- Smart contract code unless Compose CLI is reading, validating, comparing, or reporting it.

## Rules

### Command entrypoint

Only parse input, create context, call the main pipeline, and handle final output.

### Context

Context carries `param`, `config`, `state`, and `status`.

Context should not own behavior.

Modules may write only their own `ctx.state.<stepName>`.

### Pipeline

Pipeline owns orchestration.

It may call modules, child pipelines, and dependency resolver.

It should not contain business logic.

It should not call external libraries directly.

### Child pipeline

Use child pipelines for isolated groups of module steps or concurrency boundaries.

Keep nesting shallow:

```txt
Main Pipeline
  -> Child Pipeline
```

Avoid deeper nesting unless strongly justified.

### Module

Module owns feature logic.

A module function receives `ctx`, optionally receives `deps`, writes its own state, and returns `ctx`.

Modules should not create adapters directly.

Files that contain helper functions and exported modules should be structured in this order:

```ts
// =====================
// Helper
// =====================

// =====================
// Modules
// =====================
```

Keep private helper functions above the exported module object. Keep the exported module object under the `// Modules` section.

Add a short 1-2 line comment above each function to explain what it does.

### Adapter

Adapter owns external communication.

Use adapters for RPC, external APIs, external tools, runtime-specific concerns, or libraries likely to change.

Adapter should not own domain validation.

### Resolver and registry

Resolver is lightweight dependency resolution, not a full DI container.

Pipeline requests dependencies.

Registry maps keys to adapter factories.

Resolver creates only requested dependencies.

Modules receive dependencies through function parameters.

## Boundary guide

Put code in:

```txt
Command      => CLI parsing and pipeline selection
Context      => shared execution state
Pipeline     => workflow order and dependency resolution
ChildPipeline=> isolated module group / concurrency boundary
Module       => feature logic and validation
Adapter      => external communication
Resolver     => create requested dependencies
Registry     => map dependency key to factory
```

## Generation workflow

When generating code:

1. Identify command workflow.
2. Define context input.
3. Choose main pipeline or child pipeline.
4. List module steps.
5. Identify external dependencies.
6. Define adapter interface.
7. Add dependency key and registry factory.
8. Resolve deps in pipeline.
9. Pass deps into module.
10. Ensure each module writes only its own state.

## Review workflow

When reviewing code, check:

1. Is command entrypoint thin?
2. Is pipeline only orchestration?
3. Is business logic inside modules?
4. Are external calls behind adapters?
5. Are deps resolved at pipeline level?
6. Do modules receive deps instead of creating adapters?
7. Is child pipeline nesting shallow?
8. Does context carry state without owning behavior?

## Output format

For generation:

1. File tree
2. Code
3. Short explanation

For review:

1. Verdict
2. Violations
3. Fixes
4. Patch or corrected code
5. Remaining risks
