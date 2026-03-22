# {{projectName}}

## Compose

Hardhat 3 diamond starter scaffolded by the [Compose CLI](https://github.com/Perfect-Abstractions/Compose). Uses `mocha` for TypeScript tests and `ethers` for chain interactions and the `@perfect-abstractions/compose` library for diamond infrastructure facets.

Includes Foundry-compatible Solidity tests, `mocha` integration tests, simulated networks (including OP-style chains in config), a `Diamond` built with Compose `DiamondMod` and `OwnerMod`, and a simple `CounterFacet`.

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

Run only Solidity or only Mocha tests:

```sh
npx hardhat test solidity
npx hardhat test mocha
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
