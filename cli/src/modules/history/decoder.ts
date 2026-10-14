import { decodeEventLog, type Log } from "viem";
import type { IRPCAdapter } from "../../adapters/IRPCAdapter/interface";
import { historyEvents } from "./events";
import type { HistoryEvent } from "./types";

function completeLog(log: Log): asserts log is Log<bigint, number, false> {
  if (log.blockNumber === null || log.transactionHash === null || log.transactionIndex === null || log.logIndex === null) {
    throw new Error("History log is missing block or transaction position");
  }
}

/** Decode event parameters from their ABI, preserving their declared order. */
export async function decodeHistoryLogs(rpc: IRPCAdapter, logs: Log[]): Promise<HistoryEvent[]> {
  const timestampByBlock = new Map<bigint, bigint>();
  const result: HistoryEvent[] = [];

  for (const log of logs) {
    completeLog(log);
    const decoded = decodeEventLog({ abi: historyEvents, data: log.data, topics: log.topics });
    const event = historyEvents.find((item) => item.name === decoded.eventName);
    if (!event) throw new Error(`Unknown ERC-8153 event: ${decoded.eventName}`);

    let timestamp = timestampByBlock.get(log.blockNumber);
    if (timestamp === undefined) {
      timestamp = await rpc.getBlockTimestamp(log.blockNumber);
      timestampByBlock.set(log.blockNumber, timestamp);
    }

    const args = decoded.args as Record<string, unknown>;
    result.push({
      blockNumber: log.blockNumber,
      timestamp,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
      name: decoded.eventName,
      parameters: event.inputs.map((input) => ({ name: input.name, type: input.type, value: args[input.name] })),
    });
  }

  return result.sort((left, right) => {
    if (left.blockNumber !== right.blockNumber) return left.blockNumber < right.blockNumber ? 1 : -1;
    return right.transactionIndex - left.transactionIndex || right.logIndex - left.logIndex;
  });
}
