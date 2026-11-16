import type { Address } from "viem";

/** Non-secret Compose account alias and its framework-native reference. */
export type ComposeAccountProfile = {
  /** Public address expected from this account on every configured framework. */
  address: Address;
  /** Foundry keystore alias. Hardhat selects the configured signer by address. */
  foundryAccount?: string;
};

/** Account information resolved for one deployment. */
export type DeploymentAccount = ComposeAccountProfile & {
  alias: string;
};

/** Account entry rendered by `compose account list`. */
export type AccountListEntry = {
  alias: string;
  address: string;
  foundryAccount?: string;
};

/** Chain default rendered by `compose account list`. */
export type AccountChainDefault = {
  chainKey: string;
  alias: string;
};

/** Result of a successful `compose account check`. */
export type AccountCheckSummary = {
  alias: string;
  address: string;
  chainKey: string;
};

/** Result of a successful `compose account setup`. */
export type AccountSetupSummary = {
  alias: string;
  address: string;
  framework: "foundry" | "hardhat";
  foundryAccount?: string;
  /** Whether the referenced Foundry keystore file already exists. */
  foundryKeystoreExists: boolean;
  /** Hardhat key variable users must configure in `hardhat.config.ts`. */
  keyVariableName?: string;
  /** Chain that now defaults to this alias. */
  chainKey?: string;
};

/** Result recorded in `ctx.state.account` after a successful action. */
export type AccountActionResult =
  | ({ action: "setup" } & AccountSetupSummary)
  | ({ action: "check" } & AccountCheckSummary)
  | { action: "list"; entries: AccountListEntry[]; defaults: AccountChainDefault[] }
  | { action: "remove"; alias: string };
