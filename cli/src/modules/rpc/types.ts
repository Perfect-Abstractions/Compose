import type { Address } from "viem";

export type RPCCheckResult = {
  chainKey: string;
  chainId: number;
  address?: Address;
  hasCode?: boolean;
};
