import fs from "node:fs";
import { IFrameworkAdapter } from "../../adapters/interface/IFrameworkAdapter";
import { getNewestSourceMtime, getOldestArtifactMtime, detectFramework } from "./utils";

export { detectFramework };

export function areArtifactsStale(projectRoot: string, adapter: IFrameworkAdapter): boolean {
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
}

export async function compileIfNeeded(projectRoot: string, adapter: IFrameworkAdapter): Promise<void> {
  if (!areArtifactsStale(projectRoot, adapter)) {
    console.log("No file change")
    return;
  }

  await adapter.compile(projectRoot);
}
