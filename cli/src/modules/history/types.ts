import type { Address, Hex } from "viem";

export type HistoryParameter = {
  name: string;
  type: string;
  value: unknown;
};

export type HistoryEvent = {
  blockNumber: bigint;
  timestamp: bigint;
  transactionHash: Hex;
  transactionIndex: number;
  logIndex: number;
  name: string;
  parameters: HistoryParameter[];
};

export type HistoryResult = {
  diamond: Address;
  chainKey: string;
  chainId: number;
  events: HistoryEvent[];
};
