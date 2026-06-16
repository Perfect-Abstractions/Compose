# Review Checklist

## Clean

- Command entrypoint is thin.
- Pipeline reads like workflow table of contents.
- Modules own business logic.
- Files with helpers place private helpers under the `Helper` banner before exported modules under the `Modules` banner.
- Functions have a short 1-2 line comment explaining what they do.
- Adapters own external communication.
- Resolver is lightweight.
- Registry only maps keys to factories.
- Context carries state.
- Child pipeline nesting is shallow.

## Red flags

- Pipeline calls `viem`, `ethers`, APIs, or subprocess directly.
- Module creates adapter directly.
- Helper functions are mixed below exported module objects.
- Adapter validates domain rules.
- Resolver becomes full DI container.
- Context becomes service locator.
- Child pipeline nests too deep.
- One function does command + pipeline + module + adapter work.
