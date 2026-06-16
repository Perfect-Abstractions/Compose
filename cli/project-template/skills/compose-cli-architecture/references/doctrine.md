# Compose CLI Doctrine

## Architecture

Compose CLI uses Pipeline-Oriented Modular Architecture.

The CLI is one-shot, Node.js-based, and should not hold, store, or transmit private keys.

## Context shape

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

## Dependency resolver shape

```ts
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

const DependencyResolver = {
  async resolve(
    requests: DependencyRequest[]
  ): Promise<Record<string, unknown>> {
    const deps: Record<string, unknown> = {};

    for (const request of requests) {
      const factory = DependencyRegistry[request.key];

      if (!factory) {
        throw new Error(`Dependency factory not found: ${request.key}`);
      }

      deps[request.key] = await factory(request.params);
    }

    return deps;
  },
};
```

## Main boundary sentence

```txt
Pipeline decides order.
Module decides meaning.
Adapter handles outside world.
Resolver creates dependencies.
Context records the trace.
```