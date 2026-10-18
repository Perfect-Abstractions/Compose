import type { ComposeContext } from "../../context/types";
import { atomicWriteFile, pathExists } from "../../utils/files";
import { ConfigModule } from "../config/module";
import type { BasesCatalog } from "../config/types";
import { applyInstallBatch, applyRemoveBatch } from "./batchMutation";
import {
  contractReferenceName,
  resolveFacetInstallReference,
  type FacetReferenceResolutionOptions,
} from "./facetResolver";
import {
  createInstallFacetBatch,
  createRemoveFacetBatch,
  readFacetBatch,
  resolveExistingFacetBatchPath,
  resolveFacetBatchPath,
  serializeFacetBatch,
} from "./manifest";
import { showFacetManifestCreated } from "./output";
import { getDiamondOrThrow } from "./projectConfig";
import type { LoadedComposeProject } from "./projectConfig";
import {
  confirmRemoval,
  facetReferenceOptions,
  selectInstallReferences,
  selectRemoveFacetNames,
} from "./selection";
import type {
  FacetBatch,
  FacetBatchOperation,
  FacetInstallReference,
  FacetMutationResult,
} from "./types";

/** Wraps a CLI argument (`name` or `path.sol:Contract`) as a batch reference. */
function catalogManifestReference(value: string): FacetInstallReference {
  const name = contractReferenceName(value);
  return name ? { name, source: "local", contract: value } : { name: value };
}

/** Writes a `--create-manifest` batch for review instead of touching compose.json. */
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
      // Install reaches this with resolved references; remove with plain names.
      facets: references.map((reference) =>
        typeof reference === "string" ? reference : reference.name,
      ),
    }],
    changed: false,
    manifestPath,
  };
  showFacetManifestCreated(result);
  return ctx;
}

/** Rewrites CLI references as the fully-resolved form a manifest should store. */
async function normalizeInstallManifestReferences(
  references: string[],
  catalog: BasesCatalog,
  projectRoot: string,
  options?: FacetReferenceResolutionOptions,
): Promise<FacetInstallReference[]> {
  const normalized: FacetInstallReference[] = [];
  for (const reference of references) {
    const resolved = await resolveFacetInstallReference(reference, catalog, projectRoot, options);
    const localContract = resolved.registration.source === "local" && !resolved.catalogSource
      ? resolved.registration.contract
      : "";
    normalized.push(localContract
      ? {
          name: resolved.name,
          source: "local",
          contract: localContract,
        }
      : { name: resolved.name });
  }
  return normalized;
}

/** Reads the batch file named by --manifest. */
async function readManifestBatch(
  ctx: ComposeContext,
  project: LoadedComposeProject,
  operation: FacetBatchOperation,
): Promise<FacetBatch> {
  const manifestPath = await resolveExistingFacetBatchPath(project.root, String(ctx.param.manifest));
  return readFacetBatch(manifestPath, operation);
}

/** Manifest replay: resolves the batch's references and registers every diamond in it. */
export async function installFromManifest(ctx: ComposeContext, project: LoadedComposeProject): Promise<ComposeContext> {
  ctx = await ConfigModule.loadBasesCatalog(ctx);
  const batch = await readManifestBatch(ctx, project, "install");
  return applyInstallBatch(ctx, project, batch);
}

/** Manifest replay: confirms, then unregisters every diamond in the batch. */
export async function removeFromManifest(ctx: ComposeContext, project: LoadedComposeProject): Promise<ComposeContext> {
  const batch = await readManifestBatch(ctx, project, "remove");
  const facetNames = Object.values(batch.diamonds).flat() as string[];
  await confirmRemoval(ctx, facetNames);
  return applyRemoveBatch(ctx, project, batch);
}

/** Direct install: references come from arguments or a prompt; register them or author a manifest. */
export async function installSelectedFacets(
  ctx: ComposeContext,
  project: LoadedComposeProject,
  diamondName: string,
): Promise<ComposeContext> {
  ctx = await ConfigModule.loadBasesCatalog(ctx);
  const catalog = ctx.config.bases as BasesCatalog;
  const diamond = getDiamondOrThrow(project.config.diamonds, diamondName);
  const references = await selectInstallReferences(ctx, catalog, diamondName, Object.keys(diamond.facets));

  if (ctx.param.createManifest) {
    const normalized = await normalizeInstallManifestReferences(
      references,
      catalog,
      project.root,
      facetReferenceOptions(),
    );
    return createManifest(ctx, project, "install", diamondName, normalized);
  }

  const batch = createInstallFacetBatch({ [diamondName]: references.map(catalogManifestReference) });
  return applyInstallBatch(ctx, project, batch);
}

/** Direct remove: names come from arguments or a prompt; confirm and unregister, or author a manifest. */
export async function removeSelectedFacets(
  ctx: ComposeContext,
  project: LoadedComposeProject,
  diamondName: string,
): Promise<ComposeContext> {
  const diamond = getDiamondOrThrow(project.config.diamonds, diamondName);
  const references = await selectRemoveFacetNames(ctx, diamondName, diamond.facets);

  if (ctx.param.createManifest) {
    return createManifest(ctx, project, "remove", diamondName, references);
  }

  await confirmRemoval(ctx, references);
  return applyRemoveBatch(ctx, project, createRemoveFacetBatch({ [diamondName]: references }));
}
