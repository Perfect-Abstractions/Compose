import fs from "node:fs/promises";
import path from "node:path";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import type { IHashingAdapter } from "../../adapters/IHashingAdapter/interface";
import type { ComposeContext, ModuleState } from "../../context/types";
import { DependencyKey } from "../../resolver/dependencyKey";
import { DependencyResolver } from "../../resolver/dependencyResolver";
import { toPosixPath } from "../../utils/files";
import { yellow } from "../../utils/terminal";
import type { BasesCatalog } from "../config/types";
import { ValidationModule } from "../validation/module";
import { loadValidationProject } from "../validation/project";
import { copyCatalogFacetSources, resolveFacetInstallReference } from "./facetResolver";
import { showFacetMutation } from "./output";
import { getDiamondOrThrow, writeComposeProject } from "./projectConfig";
import type { LoadedComposeProject } from "./projectConfig";
import { facetReferenceOptions } from "./selection";
import type {
  ComposeDiamondConfig,
  FacetBatch,
  FacetBatchOperation,
  FacetInstallReference,
  FacetMutationResult,
  ResolvedFacetInstall,
} from "./types";

function moduleState<T>(ctx: ComposeContext, key: string): ModuleState<T> | undefined {
  return ctx.state[key] as ModuleState<T> | undefined;
}

function frameworkDependency(framework: string): DependencyKey {
  if (framework === "foundry") return DependencyKey.Foundry;
  if (framework === "hardhat") return DependencyKey.Hardhat;
  throw new Error(`Unsupported framework in compose.json: ${framework || "missing"}.`);
}

function sameRegistration(left: unknown, right: unknown): boolean {
  if (!left || !right || typeof left !== "object" || typeof right !== "object") return false;
  const a = left as Record<string, unknown>;
  const b = right as Record<string, unknown>;
  return a.source === b.source && a.contract === b.contract && a.package === b.package;
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

async function resolveFrameworkAdapter(ctx: ComposeContext): Promise<{
  adapter: IFrameworkAdapter;
}> {
  const framework = frameworkDependency(String(ctx.param.framework ?? ""));
  const dependencies = await DependencyResolver.resolve([{ key: framework }]);
  const adapter = dependencies[framework] as IFrameworkAdapter | undefined;
  if (!adapter) throw new Error(`${String(ctx.param.framework)} adapter was not resolved.`);
  return { adapter };
}

/** Per-operation steps for {@link applyBatch}: what differs, nothing else. */
type FacetBatchMutation = {
  operation: FacetBatchOperation;
  editDiamond(options: {
    diamondName: string;
    diamond: ComposeDiamondConfig;
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
  const projectConfig = structuredClone(project.config);
  const diamonds = projectConfig.diamonds;
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
      await writeComposeProject(project, projectConfig);
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

/** Registers every facet in the batch, copying catalog sources as needed. */
export async function applyInstallBatch(
  ctx: ComposeContext,
  project: LoadedComposeProject,
  batch: FacetBatch,
): Promise<ComposeContext> {
  const { adapter } = await resolveFrameworkAdapter(ctx);
  const contractSourceRoot = adapter.getContractSourceRoot(project.root);
  const catalog = ctx.config.bases as BasesCatalog;
  const resolution = facetReferenceOptions();

  return applyBatch(ctx, project, batch, {
    operation: "install",
    editDiamond: async ({ diamondName, diamond, entries, stagedFiles }) => {
      const resolved: ResolvedFacetInstall[] = [];
      for (const reference of entries as FacetInstallReference[]) {
        resolved.push(await resolveFacetInstallReference(reference, catalog, project.root, resolution));
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

/** Unregisters every facet in the batch, skipping names that are not registered. */
export async function applyRemoveBatch(
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
