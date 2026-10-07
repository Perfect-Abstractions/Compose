import { ComposeContext } from "../context/types";
import { InspectModule, inspectAddress } from "../modules/inspect/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";
import { resolveChainConfig } from "../utils/chainConfig";

/** Diamond inspect pipeline for querying on-chain facets and selectors. */
export const InspectPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    inspectAddress(ctx.param.address);
    const chainKey = typeof ctx.param.chain === "string" ? ctx.param.chain : "local";
    const chain = await resolveChainConfig({ chainKey });
    const dependencies = await DependencyResolver.resolve([{
      key: DependencyKey.Diamond,
      params: { chainKey: chain.chainKey },
    }]);
    const diamond = dependencies[DependencyKey.Diamond];
    if (!diamond) throw new Error("Diamond dependency was not resolved");
    return InspectModule.inspect(ctx, diamond, chain);
  },
};
