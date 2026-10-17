import type { Hex } from "viem";

/** The normalized result of a managed deploy script run. */
export type DeployExecutionResult = {
  diamond: Hex;
  facets: Record<string, Hex>;
  transactions: {
    diamond: Hex;
  };
};

/** Permissive shape of the JSON written by the managed script. */
export type DeployResultFile = {
  mode?: unknown;
  planHash?: unknown;
  framework?: unknown;
  chainKey?: unknown;
  chainId?: unknown;
  instance?: unknown;
  diamond?: unknown;
  facets?: unknown;
  transactions?: unknown;
};
