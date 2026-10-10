import type { AbiEvent, Address, Log } from "viem";
import type { IRPCAdapter } from "../../adapters/IRPCAdapter/interface";
import { errorText, statusCode } from "../../adapters/IRPCAdapter/utils";

const BLOCK_WINDOW = 100_000n;
const RANGE_LIMIT = /block range|range of blocks|block span|too many (results|logs)|query returned more than|response size|limit exceeded|exceed.{0,40}(block|result|log)|max.{0,30}(block|range)/;

async function queryRange(
  rpc: IRPCAdapter,
  address: Address,
  events: readonly AbiEvent[],
  fromBlock: bigint,
  toBlock: bigint,
): Promise<Log[]> {
  try {
    return await rpc.getLogs(address, events, fromBlock, toBlock);
  } catch (error) {
    if (fromBlock === toBlock || (statusCode(error) !== 413 && !RANGE_LIMIT.test(errorText(error)))) throw error;
    const middle = (fromBlock + toBlock) / 2n;
    const first = await queryRange(rpc, address, events, fromBlock, middle);
    const second = await queryRange(rpc, address, events, middle + 1n, toBlock);
    return [...first, ...second];
  }
}

/** Query a stable chain head in bounded windows and split provider-limited ranges. */
export async function loadHistoryLogs(rpc: IRPCAdapter, address: Address, events: readonly AbiEvent[]): Promise<Log[]> {
  const head = await rpc.getBlockNumber();
  const logs: Log[] = [];
  for (let fromBlock = 0n; fromBlock <= head; fromBlock += BLOCK_WINDOW) {
    const toBlock = fromBlock + BLOCK_WINDOW - 1n > head ? head : fromBlock + BLOCK_WINDOW - 1n;
    logs.push(...await queryRange(rpc, address, events, fromBlock, toBlock));
  }
  return logs;
}
