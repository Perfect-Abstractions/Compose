import path from "node:path";
import { describe, expect, it } from "vitest";
import { hardhatAdapter } from "../../../../src/adapters/IFrameworkAdapter/hardhatAdapter/adapter";
import { createDeploymentMetadataHarness } from "./deploymentHarness";

describe("Hardhat deployment metadata", () => {
  it.each([
    ["@nomicfoundation/hardhat-ethers", "ethers"],
    ["@nomicfoundation/hardhat-toolbox-mocha-ethers", "ethers"],
    ["@nomicfoundation/hardhat-viem", "viem"],
    ["@nomicfoundation/hardhat-toolbox-viem", "viem"],
  ])("detects %s", async (plugin, expected) => {
    const harness = await createDeploymentMetadataHarness();
    try {
      await harness.writePackages({ [plugin]: "1.0.0" });
      expect(await hardhatAdapter.getDeploymentToolbox(harness.projectRoot)).toBe(expected);
    } finally { await harness.cleanup(); }
  });

  it("requires an explicit choice when both or neither deployment APIs are declared", async () => {
    const harness = await createDeploymentMetadataHarness();
    try {
      await harness.writePackages({});
      await expect(hardhatAdapter.getDeploymentToolbox(harness.projectRoot)).rejects.toThrow("Cannot determine");
      await harness.writePackages({ "@nomicfoundation/hardhat-ethers": "1", "@nomicfoundation/hardhat-viem": "1" });
      await expect(hardhatAdapter.getDeploymentToolbox(harness.projectRoot)).rejects.toThrow("Cannot determine");
    } finally { await harness.cleanup(); }
  });

  it("distinguishes equal contract names by compiler source path and resolves npm artifact aliases", async () => {
    const harness = await createDeploymentMetadataHarness();
    try {
      await harness.writeArtifact("contracts/a/Facet.sol", "project/contracts/a/Facet.sol");
      await harness.writeArtifact("contracts/b/Facet.sol", "project/contracts/b/Facet.sol");
      await harness.writeArtifact("@sample/facets/Facet.sol", "npm/@sample/facets@1.2.3/Facet.sol");
      const resolve = (source: string) => hardhatAdapter.getDeploymentContractReference(harness.projectRoot, path.join(harness.projectRoot, source), "Facet");
      expect(await resolve("contracts/b/Facet.sol")).toBe("contracts/b/Facet.sol:Facet");
      expect(await resolve("node_modules/@sample/facets/Facet.sol")).toBe("@sample/facets/Facet.sol:Facet");
      await expect(resolve("missing/Facet.sol")).rejects.toThrow("artifact not found or ambiguous");
    } finally { await harness.cleanup(); }
  });
});
