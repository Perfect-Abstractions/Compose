import { ComposeContext } from "../context/types";
import { RPCModule } from "../modules/rpc/module";

/** RPC smoke-test pipeline for validating a configured chain endpoint. */
export const RPCPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    return RPCModule.check(ctx);
  },
};
