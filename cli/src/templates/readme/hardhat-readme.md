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
npm run test
```

## Deploy Locally

Start a local Ethereum node:

```shell
npx hardhat node
```

Deploy to the local network (in a separate terminal):

```shell
npx hardhat run scripts/deploy.ts --network localhost
```

## Deploy

```shell
npx hardhat run scripts/deploy.ts --network <network_name>
```

## Learn More

- [Hardhat Documentation](https://hardhat.org/docs)
- [Compose Documentation](https://compose.diamonds)
