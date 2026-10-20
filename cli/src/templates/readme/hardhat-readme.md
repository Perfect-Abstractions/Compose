# {{PROJECT_NAME}}

Scaffolded by [Compose CLI](https://compose.diamonds) - The open-source toolkit for building modular smart contracts system on the Diamond architecture.

## Prerequisites

- [Node.js](https://nodejs.org/) (v20 or later)

## Install Dependencies

```shell
npm install
```

## Build

```shell
npm run build
```

## Test

```shell
npx compose test
```

## Deploy

Start a local Ethereum node:

```shell
npx hardhat node
```

Plan the deployment and generate the managed deploy script (in a separate terminal):

```shell
npx compose deploy
```

Review the script, then run it against the local chain:

```shell
npx compose deploy --broadcast
```

The Compose CLI is a dev dependency of this project, so `npx compose` always runs the local version.

## Learn More

- [Hardhat Documentation](https://hardhat.org/docs)
- [Compose Documentation](https://compose.diamonds)
