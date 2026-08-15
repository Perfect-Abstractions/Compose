import { isAddress, type Address } from "viem";
import { ComposeContext } from "../../context/types";
import { DependencyKey } from "../../resolver/dependencyKey";
import { DependencyResolver } from "../../resolver/dependencyResolver";
import { resolveChainConfig } from "../../utils/chainConfig";
import { showRPCCheck } from "./output";
import type { RPCCheckResult } from "./types";

/** Runs the CLI's real-RPC smoke test without domain-specific contract logic. */
export const RPCModule = {
  async check(ctx: ComposeContext): Promise<ComposeContext> {
    const chainKey = typeof ctx.param.chain === "string" ? ctx.param.chain : "local";
    const configuredChain = await resolveChainConfig({ chainKey });
    const addressValue = ctx.param.address;

    let address: Address | undefined;
    if (addressValue !== undefined) {
      if (typeof addressValue !== "string" || !isAddress(addressValue, { strict: false })) {
        throw new Error(`Invalid contract address: ${String(addressValue)}`);
      }
      address = addressValue as Address;
    }

    const dependencies = await DependencyResolver.resolve([{
      key: DependencyKey.RPC,
      params: { chainKey: configuredChain.chainKey },
    }]);
    const rpc = dependencies[DependencyKey.RPC];
    if (!rpc) throw new Error("RPC dependency was not resolved");

    let hasCode: boolean | undefined;
    if (address) {
      const code = await rpc.getCode(address);
      hasCode = Boolean(code && code !== "0x");
    }

    const result: RPCCheckResult = {
      chainKey: configuredChain.chainKey,
      chainId: configuredChain.chainId,
      ...(address ? { address, hasCode } : {}),
    };

    ctx.state.rpcCheck = { success: true, result, error: null };
    showRPCCheck(result);
    return ctx;
  },
};
