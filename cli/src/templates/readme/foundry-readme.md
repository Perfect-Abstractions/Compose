# {{PROJECT_NAME}}

Scaffolded by [Compose CLI](https://compose.diamonds) - The open-source toolkit for building modular smart contracts system on the Diamond architecture.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (v20 or later) for the Compose CLI

## Install Dependencies

```shell
npm install
```

## Build

```shell
forge build
```

## Test

```shell
npx compose test
```

## Deploy

Start a local Ethereum node:

```shell
anvil
```

Plan the deployment and generate the managed deploy script:

```shell
npx compose deploy
```

Review the script, then run it against the local chain:

```shell
npx compose deploy --broadcast
```

The Compose CLI is a dev dependency of this project, so `npx compose` always runs the local version.

## Format

```shell
forge fmt
```

## Learn More

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Compose Documentation](https://compose.diamonds)
