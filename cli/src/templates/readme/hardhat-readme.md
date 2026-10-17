# {{PROJECT_NAME}}

Scaffolded by [Compose CLI](https://compose.diamonds) - The open-source toolkit for building modular smart contracts system on the Diamond architecture.

## Prerequisites

- [Node.js](https://nodejs.org/) (v20 or later)
- [Compose CLI](https://compose.diamonds)

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
npm run test
```

## Deploy

Start a local Ethereum node:

```shell
npx hardhat node
```

Plan the deployment and generate the managed deploy script (in a separate terminal):

```shell
compose deploy
```

Review the script, then run it against the local chain:

```shell
compose deploy --broadcast
```

## Learn More

- [Hardhat Documentation](https://hardhat.org/docs)
- [Compose Documentation](https://compose.diamonds)
