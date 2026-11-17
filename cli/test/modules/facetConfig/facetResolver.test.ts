import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import type { BasesCatalog } from "../../../src/modules/config/types";
import {
  copyCatalogFacetSources,
  findLocalContractMatches,
  listAvailableCatalogFacetNames,
  resolveFacetInstallReference,
} from "../../../src/modules/facetConfig/facetResolver";

const temporaryRoots: string[] = [];

async function createProject(): Promise<string> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-facet-resolver-"));
  temporaryRoots.push(root);
  await fs.mkdir(path.join(root, "src", "facets"), { recursive: true });
  return root;
}

async function writeSource(root: string, relativePath: string, contents: string): Promise<void> {
  const target = path.join(root, relativePath);
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, contents, "utf8");
}

afterEach(async () => {
  await Promise.all(temporaryRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("facet install choices", () => {
  it("omits catalog facets already registered on the selected diamond", () => {
    const catalog: BasesCatalog = {
      globals: {
        diamond: {
          label: "Diamond",
          required: { DiamondInspectFacet: { path: "@perfect-abstractions/compose/diamond/DiamondInspectFacet.sol" } },
          optional: { DiamondUpgradeFacet: { path: "@perfect-abstractions/compose/diamond/DiamondUpgradeFacet.sol" } },
        },
        libraries: {
          label: "Libraries",
          required: {},
          optional: { ERC165Facet: { path: "@perfect-abstractions/compose/interfaceDetection/ERC165/ERC165Facet.sol" } },
        },
      },
      features: {
        "erc-20": {
          label: "ERC-20",
          required: { ERC20DataFacet: { path: "@perfect-abstractions/compose/token/ERC20/Data/ERC20DataFacet.sol" } },
          optional: { ERC20BurnFacet: { path: "@perfect-abstractions/compose/token/ERC20/Burn/ERC20BurnFacet.sol" } },
        },
      },
    };

    expect(listAvailableCatalogFacetNames(catalog, ["DiamondInspectFacet", "ERC20DataFacet"])).toEqual([
      "DiamondUpgradeFacet",
      "ERC165Facet",
      "ERC20BurnFacet",
    ]);
  });
});

describe("bare facet references", () => {
  it("resolves a unique project source without a path", async () => {
    const root = await createProject();
    await writeSource(root, "src/facets/FeeFacet.sol", "contract FeeFacet {}\n");

    const resolved = await resolveFacetInstallReference("FeeFacet", { globals: {}, features: {} }, root);

    expect(resolved.name).toBe("FeeFacet");
    expect(resolved.registration).toEqual({
      source: "local",
      contract: "src/facets/FeeFacet.sol:FeeFacet",
      constructor: undefined,
    });
  });

  it("matches a declared contract inside a differently named source", async () => {
    const root = await createProject();
    await writeSource(root, "src/facets/fees.sol", "contract FeeCollector {}\n");

    const resolved = await resolveFacetInstallReference("FeeCollector", { globals: {}, features: {} }, root);

    expect(resolved.registration).toMatchObject({ contract: "src/facets/fees.sol:FeeCollector" });
  });

  it("prefers the catalog over a project source with the same name", async () => {
    const root = await createProject();
    await writeSource(root, "src/facets/FeeFacet.sol", "contract FeeFacet {}\n");
    const catalog: BasesCatalog = {
      globals: {},
      features: {
        fees: {
          label: "Fees",
          required: {},
          optional: { FeeFacet: { path: "@perfect-abstractions/compose/token/ERC20/Fee/FeeFacet.sol" } },
        },
      },
    };

    const resolved = await resolveFacetInstallReference("FeeFacet", catalog, root);

    expect(resolved.registration).toMatchObject({ source: "package", package: "@perfect-abstractions/compose" });
  });

  it("lists every match when several sources match and no selector is available", async () => {
    const root = await createProject();
    await writeSource(root, "src/facets/FeeFacet.sol", "contract FeeFacet {}\n");
    await writeSource(root, "src/libraries/alt/FeeFacet.sol", "contract FeeFacet {}\n");

    await expect(resolveFacetInstallReference("FeeFacet", { globals: {}, features: {} }, root))
      .rejects.toThrow(/matches several project sources:[\s\S]*src\/facets\/FeeFacet\.sol[\s\S]*src\/libraries\/alt\/FeeFacet\.sol/);
  });

  it("uses the selector's choice when several sources match", async () => {
    const root = await createProject();
    await writeSource(root, "src/facets/FeeFacet.sol", "contract FeeFacet {}\n");
    await writeSource(root, "src/libraries/alt/FeeFacet.sol", "contract FeeFacet {}\n");

    const resolved = await resolveFacetInstallReference(
      "FeeFacet",
      { globals: {}, features: {} },
      root,
      { selectLocalMatch: async (candidates) => candidates[1] },
    );

    expect(resolved.registration).toMatchObject({ contract: "src/libraries/alt/FeeFacet.sol:FeeFacet" });
  });

  it("ignores dependency and generated directories", async () => {
    const root = await createProject();
    await writeSource(root, "node_modules/pkg/FeeFacet.sol", "contract FeeFacet {}\n");
    await writeSource(root, "out/FeeFacet.sol", "contract FeeFacet {}\n");

    expect(await findLocalContractMatches("FeeFacet", root)).toEqual([]);
  });

  it("falls back to substring matches when no exact source exists", async () => {
    const root = await createProject();
    await writeSource(root, "src/facets/FeeFacetV2.sol", "contract FeeFacetV2 {}\n");

    expect(await findLocalContractMatches("FeeFacet", root)).toEqual([
      { source: "src/facets/FeeFacetV2.sol", contractName: "FeeFacetV2" },
    ]);
  });
});

describe("install guidance messages", () => {
  it("suggests discovery paths for an unknown bare reference", async () => {
    const root = await createProject();

    await expect(
      resolveFacetInstallReference("erc20", { globals: {}, features: {} }, root),
    ).rejects.toThrow(/Use a 'compose catalog' name, path\.sol:ContractName, or a project contract name/);
  });

  it("adds the manifest hint for unknown manifest entries", async () => {
    const root = await createProject();

    await expect(
      resolveFacetInstallReference({ name: "erc20" }, { globals: {}, features: {} }, root),
    ).rejects.toThrow(
      /Use a 'compose catalog' name, path\.sol:ContractName, or a project contract name\. In a manifest, give the entry a local or package source\./,
    );
  });

  it("points to local registration when a catalog copy would overwrite edited content", async () => {
    const root = await createProject();
    await writeSource(root, "fixtures/CounterDecrementFacet.sol", "// catalog version\ncontract CounterDecrementFacet {}\n");
    await writeSource(root, "contracts/facets/CounterDecrementFacet.sol", "// edited locally\ncontract CounterDecrementFacet {}\n");

    const conflict = copyCatalogFacetSources(
      [{
        name: "CounterDecrementFacet",
        contractName: "CounterDecrementFacet",
        targetGroup: "facets",
        catalogSource: path.join(root, "fixtures", "CounterDecrementFacet.sol"),
        registration: { source: "local", contract: "", constructor: undefined },
      }],
      root,
      path.join(root, "contracts"),
    );

    await expect(conflict).rejects.toThrow(
      "Facet source destination already exists with different contents: contracts/facets/CounterDecrementFacet.sol",
    );
    await expect(conflict).rejects.toThrow(
      'Keep it: compose install "contracts/facets/CounterDecrementFacet.sol:CounterDecrementFacet". Replace it: move the file, then install again.',
    );
  });
});
