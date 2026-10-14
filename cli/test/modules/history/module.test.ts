import { describe, expect, it, vi } from "vitest";
import { encodeAbiParameters, encodeEventTopics, type AbiEvent, type Address, type Hex, type Log } from "viem";
import type { IRPCAdapter } from "../../../src/adapters/IRPCAdapter/interface";
import { Context } from "../../../src/context/context";
import { historyEvents } from "../../../src/modules/history/events";
import { HistoryModule } from "../../../src/modules/history/module";

const diamond = "0x0000000000000000000000000000000000000001" as Address;
const oldFacet = "0x0000000000000000000000000000000000000002" as Address;
const newFacet = "0x0000000000000000000000000000000000000003" as Address;
const tx = `0x${"ab".repeat(32)}` as Hex;
const tag = `0x${"cd".repeat(32)}` as Hex;
const chain = { chainKey: "local", chainId: 31337, rpcUrl: "http://localhost:8545" };

function eventLog(name: string, args: Record<string, unknown>, blockNumber: bigint, logIndex: number): Log {
  const found = historyEvents.find((item) => item.name === name);
  if (!found) throw new Error(`Missing event ${name}`);
  const event: AbiEvent = found;
  const indexed = event.inputs.filter((input) => input.indexed);
  const nonIndexed = event.inputs.filter((input) => !input.indexed);
  const valueOf = (name?: string) => {
    if (!name) throw new Error("Unnamed fixture parameter");
    return args[name];
  };
  return {
    address: diamond,
    blockHash: `0x${"12".repeat(32)}`,
    blockNumber,
    transactionHash: tx,
    transactionIndex: 0,
    logIndex,
    removed: false,
    topics: encodeEventTopics({ abi: [event], eventName: name, args: Object.fromEntries(indexed.map((input) => [input.name, valueOf(input.name)])) }),
    data: encodeAbiParameters(nonIndexed, nonIndexed.map((input) => valueOf(input.name))),
  } as Log;
}

function rpc(logs: Log[], head = 10n): IRPCAdapter {
  return {
    getBlockNumber: vi.fn().mockResolvedValue(head),
    getLogs: vi.fn().mockResolvedValue(logs),
    getBlockTimestamp: vi.fn().mockResolvedValue(1_700_000_000n),
    getCode: vi.fn(),
    readContract: vi.fn(),
  };
}

describe("HistoryModule", () => {
  it("decodes all five ERC-8153 events, orders them, and prints their parameters", async () => {
    const logs = [
      eventLog("FacetAdded", { _facet: oldFacet }, 8n, 0),
      eventLog("FacetReplaced", { _oldFacet: oldFacet, _newFacet: newFacet }, 9n, 0),
      eventLog("FacetRemoved", { _facet: oldFacet }, 9n, 1),
      eventLog("DiamondDelegateCall", { _delegate: newFacet, _delegateCalldata: "0x12345678" }, 10n, 0),
      eventLog("DiamondMetadata", { _tag: tag, _data: "0x1234" }, 10n, 1),
    ];
    const adapter = rpc(logs);
    vi.mocked(adapter.readContract).mockResolvedValue("0x12345678abcdef01" as never);
    const printed = vi.spyOn(console, "log").mockImplementation(() => undefined);
    try {
      const ctx = Context.create();
      await HistoryModule.list(ctx, adapter, chain, diamond);
      const result = ctx.state.history;
      expect(result).toMatchObject({ success: true });
      if (!result || !("result" in result) || !result.result) throw new Error("Missing history result");
      const events = (result.result as { events: { name: string; parameters: { name: string; value: unknown }[] }[] }).events;
      expect(events.map((event) => event.name)).toEqual([
        "DiamondMetadata", "DiamondDelegateCall", "FacetRemoved", "FacetReplaced", "FacetAdded",
      ]);
      expect(events[0].parameters).toEqual([
        { name: "_tag", type: "bytes32", value: tag },
        { name: "_data", type: "bytes", value: "0x1234" },
      ]);
      expect(events[3].parameters.map((parameter) => parameter.value)).toEqual([oldFacet, newFacet]);
      const output = printed.mock.calls.map(([line]) => String(line)).join("\n");
      expect(output).toContain("Upgrade History:");
      expect(output).toContain("Block 10 (2023-11-14 22:13:20 UTC)");
      expect(output).toContain(`  Tx: ${tx}`);
      expect(output).toContain("  Event: DiamondMetadata");
      expect(output).toContain(`    Tag: ${tag}`);
      expect(output).toContain("    Data: 0x1234");
      expect(output).toContain(`    Old Facet: ${oldFacet}`);
      expect(output).toContain(`    New Facet: ${newFacet}`);
      expect(output).toContain("      Selectors: 0x12345678, 0xabcdef01");
      expect(adapter.readContract).toHaveBeenCalledTimes(2);
      expect(vi.mocked(adapter.readContract).mock.calls.map(([parameters]) => parameters.address).sort()).toEqual(
        [oldFacet, newFacet].sort(),
      );
      expect(adapter.getBlockTimestamp).toHaveBeenCalledTimes(3);
    } finally {
      printed.mockRestore();
    }
  });

  it("includes metadata-only history and reports an empty result without inventing facet changes", async () => {
    const printed = vi.spyOn(console, "log").mockImplementation(() => undefined);
    try {
      const ctx = Context.create();
      await HistoryModule.list(ctx, rpc([eventLog("DiamondMetadata", { _tag: tag, _data: "0x" }, 1n, 0)], 1n), chain, diamond);
      expect(ctx.state.history).toMatchObject({ result: { events: [{ name: "DiamondMetadata" }] } });

      printed.mockClear();
      await HistoryModule.list(Context.create(), rpc([], 0n), chain, diamond);
      expect(printed.mock.calls.some(([line]) => String(line).includes("No ERC-8153 events found"))).toBe(true);
    } finally {
      printed.mockRestore();
    }
  });

  it("keeps facet history when exportSelectors is unavailable or malformed", async () => {
    const adapter = rpc([
      eventLog("FacetAdded", { _facet: oldFacet }, 2n, 0),
      eventLog("FacetAdded", { _facet: newFacet }, 3n, 0),
    ]);
    vi.mocked(adapter.readContract)
      .mockRejectedValueOnce(new Error("no code"))
      .mockResolvedValueOnce("0x123456" as never);
    const printed = vi.spyOn(console, "log").mockImplementation(() => undefined);
    try {
      const ctx = Context.create();
      await HistoryModule.list(ctx, adapter, chain, diamond);
      expect(ctx.state.history).toMatchObject({ success: true });
      const output = printed.mock.calls.map(([line]) => String(line)).join("\n");
      expect((output.match(/Selectors: unavailable/g) ?? []).length).toBe(2);
    } finally {
      printed.mockRestore();
    }
  });

  it("splits provider-limited ranges and propagates persistent RPC failures", async () => {
    const adapter = rpc([], 3n);
    vi.mocked(adapter.getLogs).mockImplementation(async (_address, _events, from, to) => {
      if (to - from > 1n) throw new Error("block range too wide");
      return [];
    });
    const printed = vi.spyOn(console, "log").mockImplementation(() => undefined);
    try {
      await HistoryModule.list(Context.create(), adapter, chain, diamond);
      expect(adapter.getLogs).toHaveBeenCalledTimes(3);
      vi.mocked(adapter.getLogs).mockRejectedValue(new Error("RPC unavailable"));
      await expect(HistoryModule.list(Context.create(), adapter, chain, diamond)).rejects.toThrow("RPC unavailable");
    } finally {
      printed.mockRestore();
    }
  });
});
