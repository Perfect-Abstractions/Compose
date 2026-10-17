# {{PROJECT_NAME}}

Scaffolded by [Compose CLI](https://compose.diamonds) - The open-source toolkit for building modular smart contracts system on the Diamond architecture.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Compose CLI](https://compose.diamonds)

## Build

```shell
forge build
```

## Test

```shell
forge test
```

## Deploy

Start a local Ethereum node:

```shell
anvil
```

Plan the deployment and generate the managed deploy script:

```shell
compose deploy
```

Review the script, then run it against the local chain:

```shell
compose deploy --broadcast
```

## Format

```shell
forge fmt
```

## Learn More

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Compose Documentation](https://compose.diamonds)
