import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { findPackageFacetSourceMatches } from "../../src/utils/packageFacetSources";

const PACKAGE_NAME = "@perfect-abstractions/compose";

/** Creates a package facet in both the npm and Foundry package roots. */
async function createBothPackageRoots(projectRoot: string): Promise<{
  nodeSource: string;
  foundrySource: string;
}> {
  const nodeSource = path.join(projectRoot, "node_modules", PACKAGE_NAME, "diamond", "PackageFacet.sol");
  const foundrySource = path.join(projectRoot, "lib", "Compose", "src", "diamond", "PackageFacet.sol");

  await fs.mkdir(path.dirname(nodeSource), { recursive: true });
  await fs.mkdir(path.dirname(foundrySource), { recursive: true });
  await fs.writeFile(nodeSource, "contract PackageFacet {}", "utf8");
  await fs.writeFile(foundrySource, "contract PackageFacet {}", "utf8");

  return { nodeSource, foundrySource };
}

describe("package facet source search", () => {
  it("prefers the Foundry package root when both roots contain a match", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-package-sources-foundry-"));

    try {
      const { foundrySource } = await createBothPackageRoots(projectRoot);

      await expect(findPackageFacetSourceMatches(
        projectRoot,
        PACKAGE_NAME,
        "PackageFacet",
        { framework: "foundry" },
      )).resolves.toEqual([foundrySource]);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });

  it("prefers the node_modules package root for Hardhat", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-package-sources-hardhat-"));

    try {
      const { nodeSource } = await createBothPackageRoots(projectRoot);

      await expect(findPackageFacetSourceMatches(
        projectRoot,
        PACKAGE_NAME,
        "PackageFacet",
        { framework: "hardhat" },
      )).resolves.toEqual([nodeSource]);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });

  it("uses the node_modules root first when the framework is unknown", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-package-sources-unknown-"));

    try {
      const { nodeSource } = await createBothPackageRoots(projectRoot);

      await expect(findPackageFacetSourceMatches(projectRoot, PACKAGE_NAME, "PackageFacet"))
        .resolves.toEqual([nodeSource]);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });

  it("can skip unreadable roots for callers that historically ignored search errors", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-package-sources-unreadable-"));

    try {
      const packageRoot = path.join(projectRoot, "node_modules", "example-package");
      const foundrySource = path.join(projectRoot, "lib", "Compose", "src", "PackageFacet.sol");
      await fs.mkdir(path.dirname(packageRoot), { recursive: true });
      await fs.writeFile(packageRoot, "not a directory", "utf8");
      await fs.mkdir(path.dirname(foundrySource), { recursive: true });
      await fs.writeFile(foundrySource, "contract PackageFacet {}", "utf8");

      await expect(findPackageFacetSourceMatches(projectRoot, "example-package", "PackageFacet"))
        .rejects.toMatchObject({ code: "ENOTDIR" });
      await expect(findPackageFacetSourceMatches(
        projectRoot,
        "example-package",
        "PackageFacet",
        { ignoreReadErrors: true },
      )).resolves.toEqual([foundrySource]);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });

  it("can stop before scanning later roots after the first match", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-package-sources-first-"));

    try {
      const nodeSource = path.join(projectRoot, "node_modules", "example-package", "PackageFacet.sol");
      const foundryRoot = path.join(projectRoot, "lib", "Compose", "src");
      await fs.mkdir(path.dirname(nodeSource), { recursive: true });
      await fs.mkdir(path.dirname(foundryRoot), { recursive: true });
      await fs.writeFile(nodeSource, "contract PackageFacet {}", "utf8");
      await fs.writeFile(foundryRoot, "not a directory", "utf8");

      await expect(findPackageFacetSourceMatches(
        projectRoot,
        "example-package",
        "PackageFacet",
        { stopAfterFirstMatch: true },
      )).resolves.toEqual([nodeSource]);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });
});
