import fs from "node:fs/promises";
import path from "node:path";
import { IFrameworkAdapter } from "../../adapters/interface/IFrameworkAdapter";
import { ComposeContext, ModuleState } from "../../context/types";
import { VERSION } from "../../utils/metadata";
import { copyFileIfMissing, parsePackageName, resolveLocalSolidityImportClosure, toPosixPath } from "../../utils/files";
import { extractSolidityContractBody, parseExportedSelectorSignatures, parseSolidityFunctions } from "../../utils/solidityText";
import { contractNameFromSourcePath, isComposePackagePath, resolveCatalogSourceForRead } from "../../utils/soliditySources";
import { SeedFile, FacetScanResult, ScaffoldMapEntry } from "./types";
import { getSelectedFacets } from "./facetSelection";
import { parseStorageLayouts } from "./storage";
import { targetDirectoryForFacet } from "./paths";

/**
 * Scans selected Solidity facets and writes the final project configuration.
 *
 * Parses each facet's source file to extract contract names, functions,
 * exported selectors, and storage layouts, then writes the assembled
 * `compose.json` to the project root.
 */
export const ScaffoldingModule = {
  getSelectedFacets,
  targetDirectoryForFacet,
  parseStorageLayouts,
  /**
   * Records the framework scaffold map so later modules can resolve generated files.
   *
   * @param ctx - The compose context to receive the scaffold map state.
   * @param entries - The scaffold map entries returned by the framework adapter.
   * @returns The context with `ctx.state.scaffoldMap` populated.
   */
  recordScaffoldMap(ctx: ComposeContext, entries: ScaffoldMapEntry[]): ComposeContext {
    ctx.state.scaffoldMap = {
      success: true,
      result: { entries },
      error: null,
    };

    return ctx;
  },

  /**
   * Copies selected facet source files and their import closures into the project.
   *
   * Resolves each facet's source path, copies the file to the appropriate target
   * directory (diamond/, libraries/, or facets/), and follows relative imports
   * to copy transitive dependencies.
   *
   * @param ctx - The compose context with selected facets.
   * @param contractSourceRoot - The framework's contract source root (e.g., src/ or contracts/).
   * @returns The scaffold map entries for all copied facets.
   */
  async copyFacets(ctx: ComposeContext, contractSourceRoot: string): Promise<ScaffoldMapEntry[]> {
    const selectedFacets = getSelectedFacets(ctx);
    const localFacets = selectedFacets.filter((facet) => !isComposePackagePath(facet.entry.path));

    const allSeeds: SeedFile[] = localFacets.map((facet) => ({
      source: resolveCatalogSourceForRead(facet.entry.path),
      target: path.join(targetDirectoryForFacet(contractSourceRoot, facet), path.basename(facet.entry.path)),
    }));

    const seedSources = allSeeds.map((x) => x.source);
    const closure = await resolveLocalSolidityImportClosure(seedSources);

    const sourceToTarget = new Map<string, string>();
    for (const seed of allSeeds) {
      sourceToTarget.set(path.resolve(seed.source), seed.target);
    }

    for (const file of closure) {
      const directTarget = sourceToTarget.get(path.resolve(file));
      if (directTarget) {
        await copyFileIfMissing(file, directTarget);
        continue;
      }

      const parentSeed = allSeeds.find((seed) => file.startsWith(path.dirname(path.resolve(seed.source))));
      const baseTargetDir = parentSeed ? path.dirname(parentSeed.target) : contractSourceRoot;
      await copyFileIfMissing(file, path.join(baseTargetDir, path.basename(file)));
    }

    const localTargetByFacetName = new Map(localFacets.map((facet, index) => [facet.name, allSeeds[index].target]));
    const scaffoldMap: ScaffoldMapEntry[] = selectedFacets.map((facet) => {
      const isPackageFacet = isComposePackagePath(facet.entry.path);
      return {
        facetName: facet.name,
        contractName: contractNameFromSourcePath(facet.entry.path),
        targetPath: isPackageFacet ? facet.entry.path : String(localTargetByFacetName.get(facet.name)),
        origin: isPackageFacet ? "package" as const : "local" as const,
      };
    });

    return scaffoldMap;
  },

  /**
   * Scans all selected facets for functions, exported selectors, and storage layouts.
   *
   * For each facet the source file is read and parsed for:
   * - The contract name.
   * - All public/external functions (name, signature, visibility).
   * - Exported selector names from `exportSelectors()`.
   * - Storage layouts via ERC-8042 annotations or slot-assignment inference.
   *
   * `missingExports` (functions not in `exportSelectors`) and `extraExports`
   * (names in `exportSelectors` that don't match a function) are computed per
   * facet. Results are stored in `ctx.state.facetScan`.
   *
   * @param ctx - The compose context with selected facets in `ctx.param`.
   * @returns The context enriched with facet scan results.
   */
  async scanSelectedFacets(ctx: ComposeContext, adapter: IFrameworkAdapter): Promise<ComposeContext> {
    const selectedFacets = getSelectedFacets(ctx);
    const results: FacetScanResult[] = [];

    for (const facet of selectedFacets) {
      const resolvedPath = await adapter.resolveSoliditySourcePath(ctx, facet.entry.path);
      const source = await fs.readFile(resolvedPath, "utf8");
      const contractBody = extractSolidityContractBody(source, facet.name);
      if (contractBody === null) {
        throw new Error(`Selected facet contract not found: ${facet.name} (${facet.entry.path})`);
      }

      const functions = parseSolidityFunctions(contractBody);
      const exportedSelectors = parseExportedSelectorSignatures(contractBody, functions);
      const exportedSet = new Set(exportedSelectors);
      const functionSignatures = new Set(functions.map((fn) => fn.signature));
      const warnings: string[] = [];
      const storageScan = parseStorageLayouts(contractBody);

      if (exportedSelectors.length === 0) {
        warnings.push("exportSelectors() was not found or did not export any this.<function>.selector entries.");
      }
      warnings.push(...storageScan.warnings);

      results.push({
        facetName: facet.name,
        source: facet.source,
        path: facet.entry.path,
        contractName: facet.name,
        functions,
        exportedSelectors,
        missingExports: functions.filter((fn) => !exportedSet.has(fn.signature)).map((fn) => fn.signature),
        extraExports: exportedSelectors.filter((signature) => !functionSignatures.has(signature)),
        storageLayouts: storageScan.layouts,
        warnings,
      });
    }

    ctx.state.facetScan = {
      success: results.every((result) => result.missingExports.length === 0 && result.extraExports.length === 0),
      result: {
        facets: results,
        facetCount: results.length,
        selectorHashing: "not-computed",
        onchain: false,
      },
      error: null,
    };

    return ctx;
  },

  /**
   * Builds the `compose.json` object from the scaffold map.
   *
   * Reads `ctx.state.scaffoldMap` (populated by `recordScaffoldMap`) to
   * determine where each facet was placed. Derives contract paths relative to
   * the project root and classifies each facet origin as "local" or "package".
   *
   * M1: All facets are "local" (copied into the project). The "package" origin
   * is reserved for future use when facets reference the installed Compose
   * library via imports instead of copying source files.
   *
   * @param ctx - The compose context with `state.scaffoldMap`, `param.projectRoot`, `param.framework`, `param.projectName`.
   * @returns The context with `config.composeJson` populated.
   */
  buildComposeJson(ctx: ComposeContext, contractSourceRoot: string): ComposeContext {
    const framework = String(ctx.param.framework ?? "foundry");
    const projectName = String(ctx.param.projectName ?? "my-diamond");
    const root = String(ctx.param.projectRoot ?? "");
    const contractDir = toPosixPath(path.relative(root, contractSourceRoot));

    const scaffoldMapState = ctx.state.scaffoldMap as ModuleState<{ entries: ScaffoldMapEntry[] }> | undefined;
    const entries = scaffoldMapState?.result?.entries ?? [];

    const facetScanState = ctx.state.facetScan as ModuleState<{ facets: FacetScanResult[] }> | undefined;
    const facetScanResults = facetScanState?.result?.facets ?? [];

    const facets: Record<string, { source: string; contract: string; package?: string }> = {};
    for (const entry of entries) {
      const relativePath = toPosixPath(path.relative(root, entry.targetPath));
      if (entry.origin === "package") {
        const scanResult = facetScanResults.find((f) => f.facetName === entry.facetName);
        const sourcePath = scanResult?.path ?? entry.contractName;
        const packageName = parsePackageName(sourcePath);
        facets[entry.facetName] = {
          source: "package",
          contract: entry.contractName,
          package: packageName,
        };
      } else {
        facets[entry.facetName] = {
          source: "local",
          contract: `${relativePath}:${entry.contractName}`,
        };
      }
    }

    ctx.config.composeJson = {
      project: projectName,
      compose: VERSION,
      framework,
      diamonds: {
        [projectName]: {
          contract: `${contractDir}/Diamond.sol:Diamond`,
          facets,
        },
      },
      chains: {
        local: { rpc: "http://127.0.0.1:8545", chainId: 31337 },
      },
    };

    return ctx;
  },

  /**
   * Validates that local facet files exist at their expected paths.
   *
   * After scaffolding, checks each facet with `source: "local"` in
   * `compose.json` to verify the file was copied to the expected location.
   * Stores warnings on `ctx.state.facetFileValidation` but does not block
   * the pipeline.
   *
   * @param ctx - The compose context with `config.composeJson` and `param.projectRoot`.
   * @returns The context with `state.facetFileValidation` populated.
   */
  async validateLocalFacetFiles(ctx: ComposeContext): Promise<ComposeContext> {
    const composeJson = ctx.config.composeJson as Record<string, unknown> | undefined;
    if (!composeJson) {
      ctx.state.facetFileValidation = {
        success: true,
        result: { warnings: [] },
        error: null,
      };
      return ctx;
    }

    const root = String(ctx.param.projectRoot ?? "");
    const diamonds = composeJson.diamonds as Record<string, { facets: Record<string, { source: string; contract: string }> }> | undefined;
    const warnings: string[] = [];

    if (diamonds) {
      for (const diamond of Object.values(diamonds)) {
        for (const [name, facet] of Object.entries(diamond.facets)) {
          if (facet.source !== "local") continue;

          const contractPath = facet.contract.split(":")[0];
          const fullPath = path.resolve(root, contractPath);

          try {
            await fs.access(fullPath);
          } catch {
            warnings.push(`Local facet file not found: ${contractPath} (referenced by ${name})`);
          }
        }
      }
    }

    ctx.state.facetFileValidation = {
      success: warnings.length === 0,
      result: { warnings },
      error: null,
    };

    return ctx;
  },

  /**
   * Writes the assembled `compose.json` to the project root.
   *
   * Serializes `ctx.config.composeJson` as pretty-printed JSON and writes it
   * to `<projectRoot>/compose.json`.
   *
   * @param ctx - The compose context with `param.projectRoot` and `config.composeJson`.
   * @returns The context unchanged.
   */
  async writeComposeConfig(ctx: ComposeContext): Promise<ComposeContext> {
    const root = String(ctx.param.projectRoot ?? "");
    const composeJson = ctx.config.composeJson;

    await fs.writeFile(path.join(root, "compose.json"), `${JSON.stringify(composeJson, null, 2)}\n`, "utf8");

    return ctx;
  },
};
