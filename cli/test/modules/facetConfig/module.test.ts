import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { IFrameworkAdapter, SolidityAstSource } from "../../../src/adapters/IFrameworkAdapter/interface";
import type { IHashingAdapter } from "../../../src/adapters/IHashingAdapter/interface";
import { Context } from "../../../src/context/context";
import { DependencyKey } from "../../../src/resolver/dependencyKey";
import { DependencyResolver } from "../../../src/resolver/dependencyResolver";
import type { DependencyMap } from "../../../src/resolver/dependencyRegistry";
import { ConfigModule } from "../../../src/modules/config/module";
import type { BasesCatalog } from "../../../src/modules/config/types";
import { FacetConfigModule } from "../../../src/modules/facetConfig/module";
import { FACET_BATCH_DIRECTORY } from "../../../src/modules/facetConfig/manifest";
import { contractNameFromSourcePath } from "../../../src/utils/soliditySources";

const temporaryRoots: string[] = [];
const emptyCatalog: BasesCatalog = { globals: {}, features: {} };

async function createProject(): Promise<{
  root: string;
  ctx: ReturnType<typeof Context.create>;
  readConfig(): Promise<Record<string, unknown>>;
}> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-facet-config-"));
  temporaryRoots.push(root);
  await fs.mkdir(path.join(root, "src", "facets"), { recursive: true });
  await fs.writeFile(path.join(root, "foundry.toml"), '[profile.default]\nsrc = "src"\n', "utf8");
  await fs.writeFile(path.join(root, "src", "facets", "ExistingFacet.sol"), "contract ExistingFacet {}\n", "utf8");
  await fs.writeFile(path.join(root, "src", "facets", "KeepFacet.sol"), "contract KeepFacet {}\n", "utf8");
  await fs.writeFile(path.join(root, "src", "facets", "RemoveFacet.sol"), "contract RemoveFacet {}\n", "utf8");
  const config = {
    project: "test-project",
    compose: "0.3.0",
    framework: "foundry",
    diamonds: {
      TestDiamond: {
        contract: "src/Diamond.sol:Diamond",
        facets: {
          ExistingFacet: { source: "local", contract: "src/facets/ExistingFacet.sol:ExistingFacet" },
          KeepFacet: { source: "local", contract: "src/facets/KeepFacet.sol:KeepFacet" },
          RemoveFacet: { source: "local", contract: "src/facets/RemoveFacet.sol:RemoveFacet" },
        },
      },
    },
    chains: { local: { rpc: "http://127.0.0.1:8545", chainId: 31337 } },
  };
  await fs.writeFile(path.join(root, "compose.json"), `${JSON.stringify(config, null, 2)}\n`, "utf8");
  await fs.writeFile(path.join(root, "compose.lock"), "keep-lock-untouched\n", "utf8");

  const ctx = Context.create();
  ctx.param.projectRoot = root;
  ctx.param.framework = "foundry";
  return {
    root,
    ctx,
    readConfig: async () => JSON.parse(await fs.readFile(path.join(root, "compose.json"), "utf8")),
  };
}

function createAstSource(sourcePath: string, id: number): SolidityAstSource {
  const contractName = contractNameFromSourcePath(sourcePath);
  return {
    sourceName: sourcePath,
    ast: {
      id,
      nodeType: "SourceUnit",
      src: "0:0:0",
      absolutePath: sourcePath,
      nodes: [{
        id: id + 1,
        nodeType: "ContractDefinition",
        name: contractName,
        contractKind: "contract",
        linearizedBaseContracts: [id + 1],
        nodes: [],
        src: "0:0:0",
      }],
    },
  };
}

function mockValidationDependencies(): IFrameworkAdapter {
  const adapter = {
    getContractSourceRoot: (root: string) => path.join(root, "src"),
    getScriptRoot: (root: string) => path.join(root, "script"),
    getTestRoot: (root: string) => path.join(root, "test"),
    getArtifactDir: (root: string) => path.join(root, "out"),
    compile: vi.fn(async () => undefined),
    compileAst: vi.fn(async (_ctx, sourcePaths: string[]) =>
      sourcePaths.map((sourcePath, index) => createAstSource(sourcePath, index * 10 + 1)),
    ),
    resolveSoliditySourcePath: vi.fn(async (_ctx, sourcePath: string) => sourcePath),
    initProject: vi.fn(async () => undefined),
    writeConfig: vi.fn(async () => undefined),
  } as unknown as IFrameworkAdapter;
  const hashing: IHashingAdapter = { keccak256: () => "0x" as `0x${string}` };

  vi.spyOn(DependencyResolver, "resolve").mockImplementation(async (requests) => {
    const dependencies: Partial<DependencyMap> = {};
    for (const request of requests) {
      if (request.key === DependencyKey.Foundry) dependencies[DependencyKey.Foundry] = adapter;
      if (request.key === DependencyKey.Hashing) dependencies[DependencyKey.Hashing] = hashing;
    }
    return dependencies;
  });
  vi.spyOn(ConfigModule, "loadBasesCatalog").mockImplementation(async (ctx) => {
    ctx.config.bases = emptyCatalog;
    return ctx;
  });
  return adapter;
}

afterEach(async () => {
  vi.restoreAllMocks();
  await Promise.all(temporaryRoots.splice(0).map((root) => fs.rm(root, { recursive: true, force: true })));
});

describe("FacetConfigModule", () => {
  it("registers local facets atomically and leaves deployment state untouched", async () => {
    const project = await createProject();
    mockValidationDependencies();
    project.ctx.param.facets = ["src/facets/FeeFacet.sol:FeeFacet"];
    await fs.writeFile(path.join(project.root, "src", "facets", "FeeFacet.sol"), "contract FeeFacet {}\n", "utf8");

    const result = await FacetConfigModule.execute(project.ctx, "install");
    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, unknown> }>;

    expect(result.status.success).toBe(true);
    expect(diamonds.TestDiamond.facets.FeeFacet).toEqual({
      source: "local",
      contract: "src/facets/FeeFacet.sol:FeeFacet",
    });
    expect(await fs.readFile(path.join(project.root, "compose.lock"), "utf8")).toBe("keep-lock-untouched\n");
  });

  it("installs a bare contract name by fuzzy-matching the project source", async () => {
    const project = await createProject();
    mockValidationDependencies();
    project.ctx.param.facets = ["FeeFacet"];
    await fs.writeFile(path.join(project.root, "src", "facets", "FeeFacet.sol"), "contract FeeFacet {}\n", "utf8");

    const result = await FacetConfigModule.execute(project.ctx, "install");
    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, unknown> }>;

    expect(result.status.success).toBe(true);
    expect(diamonds.TestDiamond.facets.FeeFacet).toEqual({
      source: "local",
      contract: "src/facets/FeeFacet.sol:FeeFacet",
    });
  });

  it("rejects an ambiguous bare contract name when no picker is available", async () => {
    const project = await createProject();
    mockValidationDependencies();
    project.ctx.param.facets = ["FeeFacet"];
    await fs.writeFile(path.join(project.root, "src", "facets", "FeeFacet.sol"), "contract FeeFacet {}\n", "utf8");
    await fs.mkdir(path.join(project.root, "src", "alt"), { recursive: true });
    await fs.writeFile(path.join(project.root, "src", "alt", "FeeFacet.sol"), "contract FeeFacet {}\n", "utf8");

    await expect(FacetConfigModule.execute(project.ctx, "install"))
      .rejects.toThrow("matches several project sources");
  });

  it("treats registering an identical facet as an idempotent no-op", async () => {
    const project = await createProject();
    mockValidationDependencies();
    project.ctx.param.facets = ["src/facets/ExistingFacet.sol:ExistingFacet"];

    const result = await FacetConfigModule.execute(project.ctx, "install");

    expect(result.state.facetMutation).toMatchObject({ success: true, result: { changed: false } });
  });

  it("does not write config when an install source is missing", async () => {
    const project = await createProject();
    mockValidationDependencies();
    const before = await fs.readFile(path.join(project.root, "compose.json"), "utf8");
    project.ctx.param.facets = ["src/facets/MissingFacet.sol:MissingFacet"];

    await expect(FacetConfigModule.execute(project.ctx, "install")).rejects.toThrow("Facet source not found");

    expect(await fs.readFile(path.join(project.root, "compose.json"), "utf8")).toBe(before);
  });

  it("does not write config when candidate facet validation fails", async () => {
    const project = await createProject();
    const adapter = mockValidationDependencies();
    vi.mocked(adapter.compileAst).mockResolvedValue([]);
    const before = await fs.readFile(path.join(project.root, "compose.json"), "utf8");
    project.ctx.param.facets = ["src/facets/FeeFacet.sol:FeeFacet"];
    await fs.writeFile(path.join(project.root, "src", "facets", "FeeFacet.sol"), "contract FeeFacet {}\n", "utf8");

    await expect(FacetConfigModule.execute(project.ctx, "install")).rejects.toThrow("Facet contract not found in Solidity AST");

    expect(await fs.readFile(path.join(project.root, "compose.json"), "utf8")).toBe(before);
  });

  it("unregisters only config entries and leaves Solidity sources and lock state in place", async () => {
    const project = await createProject();
    mockValidationDependencies();
    project.ctx.param.facets = ["RemoveFacet"];

    const result = await FacetConfigModule.execute(project.ctx, "remove");
    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, unknown> }>;

    expect(result.status.success).toBe(true);
    expect(diamonds.TestDiamond.facets.RemoveFacet).toBeUndefined();
    expect(diamonds.TestDiamond.facets.KeepFacet).toBeDefined();
    await expect(fs.access(path.join(project.root, "src", "facets", "RemoveFacet.sol"))).resolves.toBeUndefined();
    expect(await fs.readFile(path.join(project.root, "compose.lock"), "utf8")).toBe("keep-lock-untouched\n");
  });

  it("unregisters a local facet addressed by its path.sol:Contract reference", async () => {
    const project = await createProject();
    mockValidationDependencies();
    vi.spyOn(console, "warn").mockImplementation(() => undefined);
    project.ctx.param.facets = ["src/facets/RemoveFacet.sol:RemoveFacet"];

    const result = await FacetConfigModule.execute(project.ctx, "remove");
    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, unknown> }>;

    expect(result.state.facetMutation).toMatchObject({ success: true, result: { changed: true } });
    expect(console.warn).not.toHaveBeenCalledWith(expect.stringContaining("is not registered"));
    expect(diamonds.TestDiamond.facets.RemoveFacet).toBeUndefined();
    expect(diamonds.TestDiamond.facets.KeepFacet).toBeDefined();
    expect(diamonds.TestDiamond.facets.ExistingFacet).toBeDefined();
  });

  it("treats inherited facet names as unregistered no-ops", async () => {
    const project = await createProject();
    const adapter = mockValidationDependencies();
    const before = await fs.readFile(path.join(project.root, "compose.json"), "utf8");
    project.ctx.param.facets = ["toString", "hasOwnProperty", "valueOf"];
    vi.spyOn(console, "warn").mockImplementation(() => undefined);

    const result = await FacetConfigModule.execute(project.ctx, "remove");

    expect(result.state.facetMutation).toMatchObject({ success: true, result: { changed: false } });
    expect(adapter.compileAst).not.toHaveBeenCalled();
    expect(await fs.readFile(path.join(project.root, "compose.json"), "utf8")).toBe(before);
  });

  it("registers a facet whose name is inherited from Object.prototype", async () => {
    const project = await createProject();
    mockValidationDependencies();
    project.ctx.param.facets = ["src/facets/toString.sol:toString"];
    await fs.writeFile(path.join(project.root, "src", "facets", "toString.sol"), "contract toString {}\n", "utf8");

    await FacetConfigModule.execute(project.ctx, "install");

    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, unknown> }>;
    expect(Object.hasOwn(diamonds.TestDiamond.facets, "toString")).toBe(true);
  });

  it("rejects inherited diamond names instead of treating them as configured", async () => {
    const project = await createProject();
    const manifestRoot = path.join(project.root, FACET_BATCH_DIRECTORY);
    await fs.mkdir(manifestRoot, { recursive: true });
    await fs.writeFile(path.join(manifestRoot, "inherited-diamond.json"), JSON.stringify({
      version: 1,
      operation: "remove",
      diamonds: { toString: ["RemoveFacet"] },
    }), "utf8");
    project.ctx.param.manifest = "inherited-diamond";

    await expect(FacetConfigModule.execute(project.ctx, "remove"))
      .rejects.toThrow("Diamond 'toString' is not defined in compose.json.");
  });

  it("rejects reserved facet names supplied directly to remove", async () => {
    const project = await createProject();
    const before = await fs.readFile(path.join(project.root, "compose.json"), "utf8");
    project.ctx.param.facets = ["__proto__"];

    await expect(FacetConfigModule.execute(project.ctx, "remove"))
      .rejects.toThrow("Facet name '__proto__' is reserved");

    expect(await fs.readFile(path.join(project.root, "compose.json"), "utf8")).toBe(before);
  });

  it("creates an install manifest under compose/facet-batches without changing compose.json", async () => {
    const project = await createProject();
    vi.spyOn(ConfigModule, "loadBasesCatalog").mockImplementation(async (ctx) => {
      ctx.config.bases = emptyCatalog;
      return ctx;
    });
    const before = await fs.readFile(path.join(project.root, "compose.json"), "utf8");
    project.ctx.param.createManifest = "register-fee";
    project.ctx.param.facets = ["src/facets/FeeFacet.sol:FeeFacet"];
    await fs.writeFile(path.join(project.root, "src", "facets", "FeeFacet.sol"), "contract FeeFacet {}\n", "utf8");

    await FacetConfigModule.execute(project.ctx, "install");

    const manifestPath = path.join(project.root, FACET_BATCH_DIRECTORY, "register-fee.json");
    expect(JSON.parse(await fs.readFile(manifestPath, "utf8"))).toEqual({
      version: 1,
      operation: "install",
      diamonds: {
        TestDiamond: [{
          name: "FeeFacet",
          source: "local",
          contract: "src/facets/FeeFacet.sol:FeeFacet",
        }],
      },
    });
    expect(await fs.readFile(path.join(project.root, "compose.json"), "utf8")).toBe(before);
  });

  it("applies a remove manifest by its default-folder name", async () => {
    const project = await createProject();
    mockValidationDependencies();
    const manifestRoot = path.join(project.root, FACET_BATCH_DIRECTORY);
    await fs.mkdir(manifestRoot, { recursive: true });
    await fs.writeFile(path.join(manifestRoot, "remove-legacy.json"), JSON.stringify({
      version: 1,
      operation: "remove",
      diamonds: { TestDiamond: ["RemoveFacet"] },
    }), "utf8");
    project.ctx.param.manifest = "remove-legacy";

    const result = await FacetConfigModule.execute(project.ctx, "remove");
    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, unknown> }>;

    expect(result.status.success).toBe(true);
    expect(diamonds.TestDiamond.facets.RemoveFacet).toBeUndefined();
    expect(diamonds.TestDiamond.facets.KeepFacet).toBeDefined();
  });

  it("applies an install manifest by its default-folder name", async () => {
    const project = await createProject();
    mockValidationDependencies();
    await fs.writeFile(path.join(project.root, "src", "facets", "FeeFacet.sol"), "contract FeeFacet {}\n", "utf8");
    const manifestRoot = path.join(project.root, FACET_BATCH_DIRECTORY);
    await fs.mkdir(manifestRoot, { recursive: true });
    await fs.writeFile(path.join(manifestRoot, "add-fees.json"), JSON.stringify({
      version: 1,
      operation: "install",
      diamonds: {
        TestDiamond: [{
          name: "FeeFacet",
          source: "local",
          contract: "src/facets/FeeFacet.sol:FeeFacet",
        }],
      },
    }), "utf8");
    project.ctx.param.manifest = "add-fees";

    const result = await FacetConfigModule.execute(project.ctx, "install");
    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, unknown> }>;

    expect(result.status.success).toBe(true);
    expect(diamonds.TestDiamond.facets.FeeFacet).toEqual({
      source: "local",
      contract: "src/facets/FeeFacet.sol:FeeFacet",
    });
  });

  it("registers package facets without copying dependency sources", async () => {
    const project = await createProject();
    mockValidationDependencies();
    const packageRoot = path.join(project.root, "node_modules", "test-facets");
    await fs.mkdir(packageRoot, { recursive: true });
    await fs.writeFile(path.join(packageRoot, "PackageFacet.sol"), "contract PackageFacet {}\n", "utf8");
    const manifestRoot = path.join(project.root, FACET_BATCH_DIRECTORY);
    await fs.mkdir(manifestRoot, { recursive: true });
    await fs.writeFile(path.join(manifestRoot, "package-facet.json"), JSON.stringify({
      version: 1,
      operation: "install",
      diamonds: {
        TestDiamond: [{
          name: "PackageFacet",
          source: "package",
          package: "test-facets",
          contract: "PackageFacet",
        }],
      },
    }), "utf8");
    project.ctx.param.manifest = "package-facet";

    await FacetConfigModule.execute(project.ctx, "install");

    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, unknown> }>;
    expect(diamonds.TestDiamond.facets.PackageFacet).toEqual({
      source: "package",
      contract: "PackageFacet",
      package: "test-facets",
    });
    await expect(fs.access(path.join(project.root, "src", "facets", "PackageFacet.sol"))).rejects.toThrow();
  });

  it("copies catalog-local facets into the framework source tree", async () => {
    const project = await createProject();
    mockValidationDependencies();
    vi.spyOn(ConfigModule, "loadBasesCatalog").mockImplementation(async (ctx) => {
      ctx.config.bases = {
        globals: {},
        features: {
          counter: {
            label: "Counter",
            required: {},
            optional: {
              CounterIncrementFacet: {
                path: "./src/templates/counter/CounterIncrementFacet.sol",
              },
            },
          },
        },
      } satisfies BasesCatalog;
      return ctx;
    });
    project.ctx.param.facets = ["CounterIncrementFacet"];

    await FacetConfigModule.execute(project.ctx, "install");

    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, { contract: string }> }>;
    expect(diamonds.TestDiamond.facets.CounterIncrementFacet.contract)
      .toBe("src/facets/CounterIncrementFacet.sol:CounterIncrementFacet");
    await expect(fs.access(path.join(project.root, "src", "facets", "CounterIncrementFacet.sol"))).resolves.toBeUndefined();
  });

  it("preserves nested import paths when copying catalog-local facets", async () => {
    const project = await createProject();
    mockValidationDependencies();
    const templateRoot = path.join(project.root, "catalog", "import-review");
    await fs.mkdir(path.join(templateRoot, "libraries"), { recursive: true });
    await fs.mkdir(path.join(templateRoot, "mods"), { recursive: true });
    await fs.writeFile(
      path.join(templateRoot, "NestedImportFacet.sol"),
      [
        'import {LibFee} from "./libraries/LibFee.sol";',
        'import {calculateReviewFee} from "./mods/FeeMod.sol";',
        "contract NestedImportFacet {}",
        "",
      ].join("\n"),
      "utf8",
    );
    await fs.writeFile(path.join(templateRoot, "libraries", "LibFee.sol"), "library LibFee {}\n", "utf8");
    await fs.writeFile(
      path.join(templateRoot, "mods", "FeeMod.sol"),
      "function calculateReviewFee() pure returns (uint256) { return 1; }\n",
      "utf8",
    );
    vi.spyOn(ConfigModule, "loadBasesCatalog").mockImplementation(async (ctx) => {
      ctx.config.bases = {
        globals: {},
        features: {
          "import-review": {
            label: "Import Review",
            required: {},
            optional: {
              NestedImportFacet: {
                path: path.join(templateRoot, "NestedImportFacet.sol"),
              },
            },
          },
        },
      } satisfies BasesCatalog;
      return ctx;
    });
    project.ctx.param.facets = ["NestedImportFacet"];

    await FacetConfigModule.execute(project.ctx, "install");

    const config = await project.readConfig();
    const diamonds = config.diamonds as Record<string, { facets: Record<string, { contract: string }> }>;
    expect(diamonds.TestDiamond.facets.NestedImportFacet.contract)
      .toBe("src/facets/NestedImportFacet.sol:NestedImportFacet");
    await expect(fs.access(path.join(project.root, "src", "facets", "NestedImportFacet.sol"))).resolves.toBeUndefined();
    await expect(fs.access(path.join(project.root, "src", "facets", "libraries", "LibFee.sol"))).resolves.toBeUndefined();
    await expect(fs.access(path.join(project.root, "src", "facets", "mods", "FeeMod.sol"))).resolves.toBeUndefined();
  });

  it("removes staged catalog source files when candidate validation fails", async () => {
    const project = await createProject();
    const adapter = mockValidationDependencies();
    vi.mocked(adapter.compileAst).mockResolvedValue([]);
    vi.spyOn(ConfigModule, "loadBasesCatalog").mockImplementation(async (ctx) => {
      ctx.config.bases = {
        globals: {},
        features: {
          counter: {
            label: "Counter",
            required: {},
            optional: {
              CounterIncrementFacet: {
                path: "./src/templates/counter/CounterIncrementFacet.sol",
              },
            },
          },
        },
      } satisfies BasesCatalog;
      return ctx;
    });
    const before = await fs.readFile(path.join(project.root, "compose.json"), "utf8");
    project.ctx.param.facets = ["CounterIncrementFacet"];

    await expect(FacetConfigModule.execute(project.ctx, "install")).rejects.toThrow("Facet contract not found in Solidity AST");

    expect(await fs.readFile(path.join(project.root, "compose.json"), "utf8")).toBe(before);
    await expect(fs.access(path.join(project.root, "src", "facets", "CounterIncrementFacet.sol"))).rejects.toThrow();
  });
});
