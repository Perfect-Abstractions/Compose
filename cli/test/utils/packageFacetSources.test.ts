import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { findPackageFacetSourceMatches } from "../../src/utils/packageFacetSources";

describe("package facet source search", () => {
  it("returns all matches in Node-package then Foundry search order", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-package-sources-"));

    try {
      const nodeSource = path.join(projectRoot, "node_modules", "example-package", "src", "PackageFacet.sol");
      const foundrySource = path.join(projectRoot, "lib", "Compose", "src", "PackageFacet.sol");
      await fs.mkdir(path.dirname(nodeSource), { recursive: true });
      await fs.mkdir(path.dirname(foundrySource), { recursive: true });
      await fs.writeFile(nodeSource, "contract PackageFacet {}", "utf8");
      await fs.writeFile(foundrySource, "contract PackageFacet {}", "utf8");

      await expect(findPackageFacetSourceMatches(projectRoot, "example-package", "PackageFacet"))
        .resolves.toEqual([nodeSource, foundrySource]);
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
