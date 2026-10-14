import type { ComposeContext } from "../context/types";
import { inspectAddress } from "../modules/inspect/module";
import { HistoryModule } from "../modules/history/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { resolveChainConfig } from "../utils/chainConfig";

/** Read and display the ERC-8153 event history of a deployed diamond. */
export const HistoryPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    const address = inspectAddress(ctx.param.address);
    const chainKey = typeof ctx.param.chain === "string" ? ctx.param.chain : "local";
    const chain = await resolveChainConfig({ chainKey });
    const dependencies = await DependencyResolver.resolve([{
      key: DependencyKey.RPC,
      params: { chainKey: chain.chainKey },
    }]);
    const rpc = dependencies[DependencyKey.RPC];
    if (!rpc) throw new Error("RPC dependency was not resolved");
    return HistoryModule.list(ctx, rpc, chain, address);
  },
};
