# {{PROJECT_NAME}}

Scaffolded by [Compose CLI](https://compose.diamonds) - The open-source toolkit for building modular smart contracts system on the Diamond architecture.

## Prerequisites

- [Node.js](https://nodejs.org/) (v22.13 or later)

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
npm test
```

## Validate

```shell
npm run validate
```

## Deploy

Start a local Ethereum node:

```shell
npx hardhat node
```

Plan the deployment and generate the managed Ignition module (in a separate terminal):

```shell
npm run deploy
```

Review `ignition/modules/ComposeDeploy.ts`, then simulate or deploy it against the local chain:

```shell
npm run deploy -- --dry-run
npm run deploy -- --broadcast
```

### Sepolia

Sepolia is preconfigured in `compose.json` and `hardhat.config.ts`. Copy `.env.example` to `.env` and set `SEPOLIA_RPC_URL`, store the deployer key with `npx hardhat keystore set SEPOLIA_PRIVATE_KEY`, then plan and broadcast:

```shell
npm run deploy -- --chain sepolia
npm run deploy -- --chain sepolia --broadcast
```

The Compose CLI is a dev dependency of this project, so the `npm run` scripts use the local version. Use `npx compose` for other Compose commands.

## Learn More

- [Hardhat Documentation](https://hardhat.org/docs)
- [Compose Documentation](https://compose.diamonds)
