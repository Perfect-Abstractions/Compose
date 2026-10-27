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
anvil
```

Plan the deployment and generate the managed deploy script:

```shell
npm run deploy
```

Review the script, then run it against the local chain:

```shell
npm run deploy -- --dry-run -- --sender "$DEPLOYER_ADDRESS"
npm run deploy -- --broadcast
```

Use `--account <alias>` instead of `--sender` when a Compose account is configured. Dry-run needs only the public sender address, not its private key.

### Sepolia

Sepolia is preconfigured in `compose.json` and `foundry.toml`. Copy `.env.example` to `.env` and set `SEPOLIA_RPC_URL`, then register a Compose account backed by a Foundry keystore entry:

```shell
npx compose account setup deployer --foundry-account <keystore-name> \
  --address <deployer-address> --chain sepolia
```

Plan and broadcast the deployment:

```shell
npm run deploy -- --chain sepolia --account deployer
npm run deploy -- --chain sepolia --account deployer --broadcast
```

The Compose CLI is a dev dependency of this project, so the `npm run` scripts use the local version. Use `npx compose` for other Compose commands.

## Format

```shell
npm run fmt
```

## Learn More

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Compose Documentation](https://compose.diamonds)
