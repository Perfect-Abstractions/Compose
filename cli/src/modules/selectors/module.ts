import type { IDiamondAdapter } from "../../adapters/IDiamondAdapter/interface";
import type { ComposeContext } from "../../context/types";
import { inspectAddress } from "../inspect/module";
import { loadDiamondSelectors } from "../inspect/selectorLoader";
import type { ResolvedChainConfig } from "../../utils/chainConfig";
import { showSelectors } from "./output";

export const SelectorsModule = {
  async list(ctx: ComposeContext, diamond: IDiamondAdapter, chain: ResolvedChainConfig): Promise<ComposeContext> {
    const result = await loadDiamondSelectors(inspectAddress(ctx.param.address), diamond, chain);
    ctx.state.selectors = { success: true, result, error: null };
    showSelectors(result);
    return ctx;
  },
};
