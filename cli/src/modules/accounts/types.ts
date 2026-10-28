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
