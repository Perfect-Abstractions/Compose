import fs from "node:fs/promises";
import path from "node:path";
import { DependencyKey } from "../../resolver/dependencyKey";
import { DependencyResolver } from "../../resolver/dependencyResolver";
import type { ComposeContext, ModuleState } from "../../context/types";
import { ConfigModule } from "../config/module";
import type { BasesCatalog } from "../config/types";
import { ValidationModule } from "../validation/module";
import { loadValidationProject } from "../validation/project";
import { loadPrompts, checkboxTheme, selectTheme } from "../../utils/inquirer";
import { atomicWriteFile, pathExists, toPosixPath } from "../../utils/files";
import { dim, yellow } from "../../utils/terminal";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import type { IHashingAdapter } from "../../adapters/IHashingAdapter/interface";
import {
  createInstallFacetBatch,
  createRemoveFacetBatch,
  readFacetBatch,
  resolveExistingFacetBatchPath,
  resolveFacetBatchPath,
  serializeFacetBatch,
} from "./manifest";
import {
  copyCatalogFacetSources,
  listAvailableCatalogFacetNames,
  listCatalogFacetNames,
  resolveFacetInstallReference,
} from "./facetResolver";
import { loadComposeProject, writeComposeProject } from "./projectConfig";
import type { LoadedComposeProject } from "./projectConfig";
import { showFacetManifestCreated, showFacetMutation } from "./output";
import type {
  FacetBatch,
  FacetBatchOperation,
  FacetInstallReference,
  FacetMutationResult,
  ResolvedFacetInstall,
} from "./types";

function isInteractive(): boolean {
  return Boolean(process.stdin.isTTY && process.stdout.isTTY);
}

function moduleState<T>(ctx: ComposeContext, key: string): ModuleState<T> | undefined {
  return ctx.state[key] as ModuleState<T> | undefined;
}

function frameworkDependency(framework: string): DependencyKey {
  if (framework === "foundry") return DependencyKey.Foundry;
  if (framework === "hardhat") return DependencyKey.Hardhat;
  throw new Error(`Unsupported framework in compose.json: ${framework || "missing"}.`);
}

function catalogManifestReference(value: string): FacetInstallReference {
  const match = value.match(/:([A-Za-z_$][A-Za-z0-9_$]*)$/);
  if (!match) return { name: value };
  return { name: match[1], source: "local", contract: value };
}

function sameRegistration(left: unknown, right: unknown): boolean {
  if (!left || !right || typeof left !== "object" || typeof right !== "object") return false;
  const a = left as Record<string, unknown>;
  const b = right as Record<string, unknown>;
  return a.source === b.source && a.contract === b.contract && a.package === b.package;
}

type MutableDiamondConfig = { contract: string; facets: Record<string, unknown> };

function getDiamondOrThrow(
  diamonds: Record<string, MutableDiamondConfig>,
  diamondName: string,
): MutableDiamondConfig {
  if (!Object.hasOwn(diamonds, diamondName)) {
    throw new Error(`Diamond '${diamondName}' is not defined in compose.json.`);
  }
  return diamonds[diamondName];
}

function markFailure(ctx: ComposeContext, failedAt: string, error: unknown): void {
  const message = error instanceof Error ? error.message : String(error);
  ctx.status = {
    success: false,
    stopped: true,
    failedAt,
    error: { code: "FACET_CONFIG_FAILED", message, nativeError: error },
  };
}

async function selectDiamond(ctx: ComposeContext, names: string[], operation: string): Promise<string> {
  if (typeof ctx.param.diamond === "string" && ctx.param.diamond.trim()) {
    if (!names.includes(ctx.param.diamond)) {
      throw new Error(`Diamond '${ctx.param.diamond}' not found. Available: ${names.join(", ")}`);
    }
    return ctx.param.diamond;
  }
  if (names.length === 1) return names[0];
  if (!isInteractive()) {
    throw new Error(`Specify --diamond for this project. Available: ${names.join(", ")}`);
  }
  const { select } = await loadPrompts();
  return select({
    message: `Select the diamond to ${operation}:`,
    choices: names.map((name) => ({ name, value: name })),
    theme: selectTheme,
  });
}

/** Shared selection skeleton: explicit arguments win, otherwise one multi-select prompt. */
async function selectFacetNames(
  ctx: ComposeContext,
  options: {
    promptMessage: string;
    withoutArgumentsMessage: string;
    choices: () => Promise<string[]>;
  },
): Promise<string[]> {
  if (Array.isArray(ctx.param.facets) && ctx.param.facets.length > 0) {
    return ctx.param.facets.filter((facet): facet is string => typeof facet === "string");
  }
  if (!isInteractive()) throw new Error(options.withoutArgumentsMessage);

  const names = await options.choices();
  const { checkbox } = await loadPrompts();
  const selected = await checkbox({
    message: options.promptMessage,
    choices: names.map((name) => ({ name, value: name })),
    theme: checkboxTheme,
  });
  if (selected.length === 0) throw new Error("No facets selected.");
  return selected;
}

async function selectInstallReferences(
  ctx: ComposeContext,
  catalog: BasesCatalog,
  diamondName: string,
  registeredFacetNames: Iterable<string>,
): Promise<string[]> {
  return selectFacetNames(ctx, {
    promptMessage: "Select facets to register:",
    withoutArgumentsMessage: "Provide facet names or path.sol:Contract references, or use --manifest.",
    choices: async () => {
      const registeredNames = [...registeredFacetNames];
      const registered = new Set(registeredNames);
      const registeredCatalogFacets = listCatalogFacetNames(catalog)
        .filter((name) => registered.has(name));
      if (registeredCatalogFacets.length > 0) {
        console.log(dim(`Already registered on ${diamondName}: ${registeredCatalogFacets.join(", ")}`));
      }
      const availableFacetNames = listAvailableCatalogFacetNames(catalog, registeredNames);
      if (availableFacetNames.length === 0) {
        throw new Error(`All selectable catalog facets are already registered on '${diamondName}'. Use a local path reference to add a custom facet.`);
      }
      return availableFacetNames;
    },
  });
}

async function selectRemoveFacetNames(
  ctx: ComposeContext,
  diamondName: string,
  configuredFacets: Record<string, unknown>,
): Promise<string[]> {
  return selectFacetNames(ctx, {
    promptMessage: `Select facets to unregister from ${diamondName}:`,
    withoutArgumentsMessage: "Provide facet names to remove, or use --manifest.",
    choices: async () => {
      const names = Object.keys(configuredFacets);
      if (names.length === 0) throw new Error(`Diamond '${diamondName}' has no registered facets.`);
      return names;
    },
  });
}

async function createManifest(
  ctx: ComposeContext,
  project: LoadedComposeProject,
  operation: FacetBatchOperation,
  diamondName: string,
  references: Array<string | FacetInstallReference>,
): Promise<ComposeContext> {
  const projectRoot = project.root;
  const manifestName = String(ctx.param.createManifest ?? "").trim();
  if (!manifestName) throw new Error("Provide a manifest name with --create-manifest <name>.");

  const manifestPath = resolveFacetBatchPath(projectRoot, manifestName);
  if (await pathExists(manifestPath)) {
    throw new Error(`Manifest already exists: ${manifestPath}. Choose another name.`);
  }

  const batch: FacetBatch = operation === "install"
    ? createInstallFacetBatch({
        [diamondName]: references.map((reference) =>
          typeof reference === "string" ? catalogManifestReference(reference) : reference,
        ),
      })
    : createRemoveFacetBatch({ [diamondName]: references as string[] });
  await atomicWriteFile(manifestPath, serializeFacetBatch(batch));

  const result: FacetMutationResult = {
    operation,
    projectRoot,
    composeJsonPath: project.path,
    diamondChanges: [{
      diamond: diamondName,
      facets: references.map((reference) =>
        typeof reference === "string"
          ? operation === "install" && reference.includes(":")
            ? reference.slice(reference.lastIndexOf(":") + 1)
            : reference
          : reference.name,
      ),
    }],
    changed: false,
    manifestPath,
  };
  ctx.state.facetManifest = { success: true, result, error: null };
  showFacetManifestCreated(result);
  return ctx;
}

async function normalizeInstallManifestReferences(
  references: string[],
  catalog: BasesCatalog,
  projectRoot: string,
): Promise<FacetInstallReference[]> {
  const normalized: FacetInstallReference[] = [];
  for (const reference of references) {
    const resolved = await resolveFacetInstallReference(reference, catalog, projectRoot);
    normalized.push(reference.includes(":")
      ? {
          name: resolved.name,
          source: "local",
          contract: resolved.registration.contract,
        }
      : { name: resolved.name });
  }
  return normalized;
}

async function validateCandidateConfig(
  ctx: ComposeContext,
  projectConfig: Record<string, unknown>,
): Promise<ComposeContext> {
  const project = await loadValidationProject(ctx, projectConfig);
  const framework = frameworkDependency(String(ctx.param.framework ?? ""));
  const dependencies = await DependencyResolver.resolve([
    { key: DependencyKey.Hashing },
    { key: framework },
  ]);
  const adapter = dependencies[framework] as IFrameworkAdapter | undefined;
  const hashing = dependencies[DependencyKey.Hashing] as IHashingAdapter | undefined;
  if (!adapter || !hashing) throw new Error("Source-validation dependencies were not resolved.");

  ctx = await ValidationModule.validateProjectSources(ctx, project, adapter, hashing);
  await ValidationModule.showReport(ctx);
  const validation = moduleState<{ checkedFacets: number }>(ctx, "validationSourceProject");
  if (!validation?.success) {
    throw new Error(validation?.error?.message ?? "Facet source validation failed.");
  }
  return ctx;
}

/** Per-operation steps for {@link applyBatch}: what differs, nothing else. */
type FacetBatchMutation = {
  operation: FacetBatchOperation;
  editDiamond(options: {
    diamondName: string;
    diamond: MutableDiamondConfig;
    entries: unknown;
    stagedFiles: string[];
  }): Promise<{ facets: string[]; changed: boolean }>;
  revert?(options: { stagedFiles: string[] }): Promise<void>;
};

/**
 * Shared write recipe: clone, edit every batch diamond, validate the candidate,
 * then write once. Nothing here is specific to installing or removing.
 */
async function applyBatch(
  ctx: ComposeContext,
  project: LoadedComposeProject,
  batch: FacetBatch,
  mutation: FacetBatchMutation,
): Promise<ComposeContext> {
  const projectConfig = structuredClone(project.config) as Record<string, unknown>;
  const diamonds = projectConfig.diamonds as Record<string, MutableDiamondConfig>;
  const changes: FacetMutationResult["diamondChanges"] = [];
  const stagedFiles: string[] = [];
  let changed = false;
  let committed = false;

  try {
    for (const [diamondName, entries] of Object.entries(batch.diamonds)) {
      const edit = await mutation.editDiamond({
        diamondName,
        diamond: getDiamondOrThrow(diamonds, diamondName),
        entries,
        stagedFiles,
      });
      changed = changed || edit.changed;
      changes.push({ diamond: diamondName, facets: edit.facets });
    }

    // Staged sources are as unverified as a registration change, and only install stages.
    if (changed || stagedFiles.length > 0) {
      ctx = await validateCandidateConfig(ctx, projectConfig);
    }
    if (changed) {
      await writeComposeProject(project, projectConfig as typeof project.config);
      ctx.config.composeJson = projectConfig;
    }
    committed = true;
  } catch (error) {
    if (!committed && mutation.revert) {
      await mutation.revert({ stagedFiles });
    }
    throw error;
  }

  const result: FacetMutationResult = {
    operation: mutation.operation,
    projectRoot: project.root,
    composeJsonPath: project.path,
    diamondChanges: changes,
    changed,
    ...(stagedFiles.length > 0
      ? { materializedFiles: stagedFiles.map((filePath) => toPosixPath(path.relative(project.root, filePath))) }
      : {}),
  };
  ctx.state.facetMutation = { success: true, result, error: null };
  showFacetMutation(result);
  return ctx;
}

async function applyInstallBatch(
  ctx: ComposeContext,
  project: LoadedComposeProject,
  batch: FacetBatch,
): Promise<ComposeContext> {
  const { adapter } = await resolveFrameworkAdapter(ctx);
  const contractSourceRoot = adapter.getContractSourceRoot(project.root);
  const catalog = ctx.config.bases as BasesCatalog;

  return applyBatch(ctx, project, batch, {
    operation: "install",
    editDiamond: async ({ diamondName, diamond, entries, stagedFiles }) => {
      const resolved: ResolvedFacetInstall[] = [];
      for (const reference of entries as FacetInstallReference[]) {
        resolved.push(await resolveFacetInstallReference(reference, catalog, project.root));
      }

      const copied = await copyCatalogFacetSources(resolved, project.root, contractSourceRoot);
      stagedFiles.push(...copied.createdFiles);

      const installedNames: string[] = [];
      for (const facet of copied.facets) {
        if (Object.hasOwn(diamond.facets, facet.name)) {
          if (!sameRegistration(diamond.facets[facet.name], facet.registration)) {
            throw new Error(`Facet '${facet.name}' is already registered to a different source in '${diamondName}'.`);
          }
          continue;
        }
        diamond.facets[facet.name] = facet.registration;
        installedNames.push(facet.name);
      }
      return { facets: installedNames, changed: installedNames.length > 0 };
    },
    revert: async ({ stagedFiles }) => {
      await Promise.all(stagedFiles.map((filePath) => fs.rm(filePath, { force: true })));
    },
  });
}

async function applyRemoveBatch(
  ctx: ComposeContext,
  project: LoadedComposeProject,
  batch: FacetBatch,
): Promise<ComposeContext> {
  return applyBatch(ctx, project, batch, {
    operation: "remove",
    editDiamond: async ({ diamondName, diamond, entries }) => {
      const removed: string[] = [];
      for (const facetName of entries as string[]) {
        if (!Object.hasOwn(diamond.facets, facetName)) {
          console.warn(yellow(`Facet '${facetName}' is not registered on '${diamondName}'; skipping.`));
          continue;
        }
        delete diamond.facets[facetName];
        removed.push(facetName);
      }
      if (Object.keys(diamond.facets).length === 0) {
        throw new Error(`Cannot remove every registered facet from '${diamondName}'.`);
      }
      return { facets: removed, changed: removed.length > 0 };
    },
  });
}

async function resolveFrameworkAdapter(ctx: ComposeContext): Promise<{
  adapter: IFrameworkAdapter;
}> {
  const framework = frameworkDependency(String(ctx.param.framework ?? ""));
  const dependencies = await DependencyResolver.resolve([{ key: framework }]);
  const adapter = dependencies[framework] as IFrameworkAdapter | undefined;
  if (!adapter) throw new Error(`${String(ctx.param.framework)} adapter was not resolved.`);
  return { adapter };
}

async function confirmRemoval(ctx: ComposeContext, names: string[]): Promise<void> {
  if (ctx.param.yes || !isInteractive()) return;
  const { confirm } = await loadPrompts();
  const accepted = await confirm({
    message: `Unregister ${names.join(", ")}? This only changes compose.json.`,
    default: false,
  });
  if (!accepted) throw new Error("Facet removal cancelled.");
}

export const FacetConfigModule = {
  async execute(ctx: ComposeContext, operation: FacetBatchOperation): Promise<ComposeContext> {
    try {
      if (ctx.param.manifest && ctx.param.createManifest) {
        throw new Error("Use either --manifest or --create-manifest, not both.");
      }
      if (ctx.param.manifest && Array.isArray(ctx.param.facets) && ctx.param.facets.length > 0) {
        throw new Error("Use either facet arguments or --manifest, not both.");
      }
      const project = await loadComposeProject(ctx);
      const names = Object.keys(project.config.diamonds);
      const selectedDiamond = ctx.param.manifest
        ? undefined
        : await selectDiamond(ctx, names, operation === "install" ? "install facets into" : "remove facets from");

      if (ctx.param.manifest && ctx.param.diamond) {
        throw new Error("The diamond is defined by the manifest; omit --diamond when using --manifest.");
      }

      if (operation === "install") {
        ctx = await ConfigModule.loadBasesCatalog(ctx);
        const catalog = ctx.config.bases as BasesCatalog;
        if (ctx.param.createManifest) {
          const diamond = project.config.diamonds[selectedDiamond as string];
          const references = await selectInstallReferences(ctx, catalog, selectedDiamond as string, Object.keys(diamond.facets));
          const normalized = await normalizeInstallManifestReferences(references, catalog, project.root);
          return createManifest(ctx, project, operation, selectedDiamond as string, normalized);
        }
        if (ctx.param.manifest) {
          const manifestPath = await resolveExistingFacetBatchPath(project.root, String(ctx.param.manifest));
          const batch = await readFacetBatch(manifestPath, "install");
          return applyInstallBatch(ctx, project, batch);
        }
        const diamond = project.config.diamonds[selectedDiamond as string];
        const references = await selectInstallReferences(ctx, catalog, selectedDiamond as string, Object.keys(diamond.facets));
        return applyInstallBatch(
          ctx,
          project,
          createInstallFacetBatch({ [selectedDiamond as string]: references.map(catalogManifestReference) }),
        );
      }

      if (ctx.param.createManifest) {
        const refs = await selectRemoveFacetNames(
          ctx,
          selectedDiamond as string,
          project.config.diamonds[selectedDiamond as string].facets,
        );
        return createManifest(ctx, project, operation, selectedDiamond as string, refs);
      }
      if (ctx.param.manifest) {
        const manifestPath = await resolveExistingFacetBatchPath(project.root, String(ctx.param.manifest));
        const batch = await readFacetBatch(manifestPath, "remove");
        const facetNames = Object.values(batch.diamonds).flat() as string[];
        await confirmRemoval(ctx, facetNames);
        return applyRemoveBatch(ctx, project, batch);
      }

      const targetDiamond = selectedDiamond as string;
      const refs = await selectRemoveFacetNames(
        ctx,
        targetDiamond,
        project.config.diamonds[targetDiamond].facets,
      );
      await confirmRemoval(ctx, refs);
      const batch = createRemoveFacetBatch({ [targetDiamond]: refs });
      return applyRemoveBatch(ctx, project, batch);
    } catch (error) {
      markFailure(ctx, `facet${operation === "install" ? "Install" : "Remove"}`, error);
      throw error;
    }
  },
};
