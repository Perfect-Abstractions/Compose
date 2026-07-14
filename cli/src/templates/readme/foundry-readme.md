# {{PROJECT_NAME}}

Scaffolded by [Compose CLI](https://compose.diamonds) - The open-source toolkit for building modular smart contracts system on the Diamond architecture.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

## Build

```shell
forge build
```

## Test

```shell
forge test
```

## Deploy Locally

Start a local Ethereum node:

```shell
anvil
```

Deploy to the local network:

```shell
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --private-key <anvil_private_key> --broadcast
```

## Deploy

```shell
forge script script/Deploy.s.sol:DeployScript --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

## Format

```shell
forge fmt
```

## Learn More

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Compose Documentation](https://compose.diamonds)
