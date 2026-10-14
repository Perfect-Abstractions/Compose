import { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";

export const CompileModule = {
  async compileProject(projectRoot: string, adapter: IFrameworkAdapter): Promise<void> {
    // Let Foundry/Hardhat evaluate their complete incremental build graph,
    // including deleted files, config changes, and imported package sources.
    await adapter.compile(projectRoot);
  },
};
