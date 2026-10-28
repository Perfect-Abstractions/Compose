# {{PROJECT_NAME}}

Scaffolded by [Compose CLI](https://compose.diamonds) - The open-source toolkit for building modular smart contracts system on the Diamond architecture.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (v20 or later) for the Compose CLI

## Install Dependencies

Install the Solidity dependencies:

```shell
forge install
```

Install the Compose CLI and Node tooling:

```shell
npm install
```

## Build

```shell
forge build
```

## Test

```shell
forge test
```

## Validate

```shell
npx compose validate
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

Review the script, then simulate or deploy it against the local chain:

```shell
npx compose deploy -- --dry-run -- --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
npx compose deploy -- --broadcast -- \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --non-interactive
```

The key above belongs to Anvil's first default account. Use it for local testing only, never on a public network.

Use `--account <alias>` instead of `--sender` when a Compose account is configured. Dry-run needs only the public sender address, not its private key.

### Sepolia

Sepolia is preconfigured in `compose.json` and `foundry.toml`. Copy `.env.example` to `.env` and set `SEPOLIA_RPC_URL`, then register a Compose account backed by a Foundry keystore entry:

```shell
npx compose account setup deployer --foundry-account <keystore-name> \
  --address <deployer-address> --chain sepolia
```

Plan and broadcast the deployment:

```shell
npx compose deploy -- --chain sepolia --account deployer
npx compose deploy -- --chain sepolia --account deployer --broadcast
```

The Compose CLI is a dev dependency of this project, so `npx compose` uses the local version.

## Format

```shell
forge fmt
```

## Learn More

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Compose Documentation](https://compose.diamonds)
