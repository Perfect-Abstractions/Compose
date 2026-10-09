import type { Address } from "viem";
import type { IRPCAdapter } from "../../adapters/IRPCAdapter/interface";
import type { ComposeContext } from "../../context/types";
import type { ResolvedChainConfig } from "../../utils/chainConfig";
import { decodeHistoryLogs } from "./decoder";
import { historyEvents } from "./events";
import { loadHistoryLogs } from "./logs";
import { showHistory } from "./output";
import type { HistoryResult } from "./types";

export const HistoryModule = {
  async list(ctx: ComposeContext, rpc: IRPCAdapter, chain: ResolvedChainConfig, address: Address): Promise<ComposeContext> {
    const logs = await loadHistoryLogs(rpc, address, historyEvents);
    const result: HistoryResult = {
      diamond: address,
      chainKey: chain.chainKey,
      chainId: chain.chainId,
      events: await decodeHistoryLogs(rpc, logs),
    };
    ctx.state.history = { success: true, result, error: null };
    showHistory(result);
    return ctx;
  },
};
