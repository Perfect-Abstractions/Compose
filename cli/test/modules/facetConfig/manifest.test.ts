import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  createInstallFacetBatch,
  createRemoveFacetBatch,
  readFacetBatch,
  resolveFacetBatchPath,
  serializeFacetBatch,
  validateFacetBatch,
} from "../../../src/modules/facetConfig/manifest";

const temporaryRoots: string[] = [];

async function createRoot(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-facet-batch-"));
  temporaryRoots.push(root);
  return root;
}

afterEach(async () => {
  await Promise.all(temporaryRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("facet batch manifests", () => {
  it("resolves simple names under compose/facet-batches", async () => {
    const root = await createRoot();
    expect(resolveFacetBatchPath(root, "add-fees")).toBe(
      path.join(root, "compose", "facet-batches", "add-fees.json"),
    );
  });

  it("round-trips install and remove manifests", async () => {
    const root = await createRoot();
    const install = createInstallFacetBatch({
      Token: [
        { name: "ERC20BurnFacet" },
        "src/facets/TransferFacet.sol:TransferFacet",
        {
          name: "FeeFacet",
          source: "local",
          contract: "src/facets/FeeFacet.sol:FeeFacet",
        },
      ],
    });
    const remove = createRemoveFacetBatch({ Token: ["LegacyFacet"] });

    const installPath = path.join(root, "install.json");
    const removePath = path.join(root, "remove.json");
    await fs.writeFile(installPath, serializeFacetBatch(install), "utf8");
    await fs.writeFile(removePath, serializeFacetBatch(remove), "utf8");

    expect(await readFacetBatch(installPath, "install")).toEqual(install);
    expect(await readFacetBatch(removePath, "remove")).toEqual(remove);
  });

  it("rejects invalid versions, empty batches, and operation mismatches", () => {
    expect(() => validateFacetBatch({ version: 2, operation: "install", diamonds: { Token: ["A"] } }))
      .toThrow("Unsupported facet batch manifest version");
    expect(() => validateFacetBatch({ version: 1, operation: "install", diamonds: {} }))
      .toThrow("at least one diamond");
    expect(() => validateFacetBatch({ version: 1, operation: "install", diamonds: { Token: ["A", "A"] } }))
      .toThrow("contains duplicate facet names");
    expect(() => validateFacetBatch({ version: 1, operation: "remove", diamonds: { Token: ["A"] } }, "install"))
      .toThrow("expects an 'install' manifest");
    expect(() => validateFacetBatch({
      version: 1,
      operation: "install",
      diamonds: { Token: [{ name: "FeeFacet", source: "local", contract: "FeeFacet.sol" }] },
    })).toThrow("must use path.sol:ContractName");
  });

  it("rejects reserved object keys as diamond and facet names", () => {
    for (const name of ["__proto__", "constructor", "prototype"]) {
      expect(() => createRemoveFacetBatch({ Token: [name] })).toThrow("Facet name");
      expect(() => createInstallFacetBatch({ Token: [{ name }] })).toThrow("Facet name");
      expect(() => createRemoveFacetBatch({ [name]: ["LegacyFacet"] })).toThrow("Diamond name");
    }
  });
});
