import fs from "node:fs";
import { IFrameworkAdapter } from "../../adapters/interface/IFrameworkAdapter";
import { getNewestSourceMtime, getOldestArtifactMtime } from "./utils";

export const CompileModule = {
  areArtifactsStale(projectRoot: string, adapter: IFrameworkAdapter): boolean {
    const artifactDir = adapter.getArtifactDir(projectRoot);

    if (!fs.existsSync(artifactDir)) {
      return true;
    }

    const sourceDir = adapter.getContractSourceRoot(projectRoot);
    const newestSource = getNewestSourceMtime(sourceDir);

    if (newestSource === null) {
      return false;
    }

    const oldestArtifact = getOldestArtifactMtime(artifactDir);

    if (oldestArtifact === null) {
      return true;
    }

    return newestSource > oldestArtifact;
  },

  async compileIfNeeded(projectRoot: string, adapter: IFrameworkAdapter): Promise<void> {
    if (!this.areArtifactsStale(projectRoot, adapter)) {
      console.log("No file change")
      return;
    }

    await adapter.compile(projectRoot);
  }
}
