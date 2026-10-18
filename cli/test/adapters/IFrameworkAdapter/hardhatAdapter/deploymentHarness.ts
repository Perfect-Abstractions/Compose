import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

/** Files consumed by the adapter's deployment metadata methods. */
export async function createDeploymentMetadataHarness() {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-hardhat-deployment-"));
  return {
    projectRoot,
    writePackages: (devDependencies: Record<string, string>) =>
      fs.writeFile(path.join(projectRoot, "package.json"), JSON.stringify({ devDependencies })),
    async writeArtifact(sourceName: string, inputSourceName: string, contractName = "Facet"): Promise<void> {
      const file = path.join(projectRoot, "artifacts", sourceName, `${contractName}.json`);
      await fs.mkdir(path.dirname(file), { recursive: true });
      await fs.writeFile(file, JSON.stringify({ sourceName, inputSourceName, contractName }));
    },
    cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }),
  };
}
