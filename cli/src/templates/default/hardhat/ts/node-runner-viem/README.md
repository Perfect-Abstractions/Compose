# {{projectName}}

## Compose

Hardhat 3 diamond starter scaffolded by the [Compose CLI](https://github.com/Perfect-Abstractions/Compose). Uses the native Node.js test runner (`node:test`) for TypeScript tests and `viem` for chain interactions and the `@perfect-abstractions/compose` library for diamond infrastructure facets.

Includes Foundry-compatible Solidity tests, `node:test` integration tests, simulated networks (including OP-style chains in config), a `Diamond` built with Compose `DiamondMod` and `OwnerMod`, and facets (`CounterFacet`, `DiamondInspectFacet`, `DiamondUpgradeFacet`).

### How to deploy

The Ignition module `ignition/modules/Counter.ts` (`CounterDiamondModule`) deploys `CounterFacet`, `DiamondInspectFacet`, and `DiamondUpgradeFacet`, then deploys `Diamond` with those facets and `accounts[0]` as the owner.

### Links

- [Docs](https://compose.diamonds/)
- [GitHub](https://github.com/Perfect-Abstractions/Compose)

---

## Hardhat usage

### Build

```sh
npx hardhat build
```

### Test

```sh
npx hardhat test
```

Run only Solidity or only Node.js tests:

```sh
npx hardhat test solidity
npx hardhat test nodejs
```

### Deploy

Deploy to a local chain:
```sh
npx hardhat ignition deploy ignition/modules/Counter.ts
```

To run the deployment to Sepolia, you need an account with funds to send the transaction. The provided Hardhat configuration includes a Configuration Variable called `SEPOLIA_PRIVATE_KEY`, which you can use to set the private key of the account you want to use.

You can set the `SEPOLIA_PRIVATE_KEY` variable using the `hardhat-keystore` plugin or by setting it as an environment variable (less recommended).

After configuring `SEPOLIA_PRIVATE_KEY` and network in `hardhat.config`:

To set the `SEPOLIA_PRIVATE_KEY` variable using `hardhat-keystore`:

```shell
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

After setting the variable, you can run the deployment with the Sepolia network:

```shell
npx hardhat ignition deploy --network sepolia ignition/modules/Counter.ts
```

### Cast

```sh
cast <subcommand>
```

### Help

```sh
npx hardhat --help
forge --help
anvil --help
cast --help
```
