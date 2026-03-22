# {{projectName}}

## Compose

Foundry diamond starter scaffolded by the [Compose CLI](https://github.com/Perfect-Abstractions/Compose). Project can use the `@perfect-abstractions/compose` library for diamond infrastructure facets.

### How to deploy

`DeployScript` deploys `CounterFacet`, `DiamondInspectFacet`, and `DiamondUpgradeFacet`, then deploys `Diamond` with those facets and `msg.sender` as the owner.

### Links
- [Docs](https://compose.diamonds/)
- [GitHub](https://github.com/Perfect-Abstractions/Compose)

---

## Foundry usage

### Build

```sh
forge build
```

### Test

```sh
forge test
```

### Format

```sh
forge fmt
```

### Gas snapshots

```sh
forge snapshot
```

### Anvil

```sh
anvil
```

### Deploy

```sh
forge script script/Deploy.s.sol:DeployScript --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

### Cast

```sh
cast <subcommand>
```

### Help

```sh
forge --help
anvil --help
cast --help
```