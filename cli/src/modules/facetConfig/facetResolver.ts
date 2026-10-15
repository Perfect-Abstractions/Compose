import { constants } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import type { BasesCatalog, FacetEntry } from "../config/types";
import {
  parsePackageName,
  planImportClosureTargets,
  resolveLocalSolidityImportClosure,
  toPosixPath,
} from "../../utils/files";
import {
  contractNameFromSourcePath,
  isComposePackagePath,
  resolveCatalogSourceForRead,
} from "../../utils/soliditySources";
import { removeSolidityComments } from "../../utils/solidityText";
import type {
  FacetInstallReference,
  FacetRegistration,
  ResolvedFacetInstall,
} from "./types";

/** A project Solidity source that fuzzy-matched a bare facet reference. */
export type LocalContractMatch = {
  /** Project-relative POSIX path of the matching source. */
  source: string;
  /** Contract name to register for the matching source. */
  contractName: string;
};

/** Hooks that let the caller resolve ambiguous bare facet references. */
export type FacetReferenceResolutionOptions = {
  /**
   * Called when a bare facet name matches several project sources.
   * Returns the chosen project-relative source path.
   */
  selectLocalMatch?: (candidates: string[]) => Promise<string>;
};

/** Dependency and generated directories excluded from bare-name source scans. */
const IGNORED_SOURCE_DIRECTORIES = new Set([
  "node_modules",
  "lib",
  "out",
  "cache",
  "artifacts",
  "broadcast",
  "broadcasts",
  "typechain-types",
  "coverage",
  "dist",
]);

const CONTRACT_DECLARATION = /\b(?:abstract\s+)?(?:contract|library|interface)\s+([A-Za-z_$][A-Za-z0-9_$]*)/g;

type CatalogCandidate = {
  name: string;
  entry: FacetEntry;
  group: "diamond" | "libraries" | "facets";
};

function catalogCandidates(catalog: BasesCatalog): CatalogCandidate[] {
  const candidates: CatalogCandidate[] = [];
  const add = (facets: Record<string, FacetEntry> | undefined, group: CatalogCandidate["group"]): void => {
    for (const [name, entry] of Object.entries(facets ?? {})) candidates.push({ name, entry, group });
  };

  add(catalog.globals.diamond?.required, "diamond");
  add(catalog.globals.diamond?.optional, "diamond");
  add(catalog.globals.libraries?.required, "libraries");
  add(catalog.globals.libraries?.optional, "libraries");
  add(catalog.globals.examples?.required, "facets");
  add(catalog.globals.examples?.optional, "facets");
  for (const definition of Object.values(catalog.features)) {
    add(definition.required, "facets");
    add(definition.optional, "facets");
  }

  const unique = new Map<string, CatalogCandidate>();
  for (const candidate of candidates) {
    const key = `${candidate.name}:${JSON.stringify(candidate.entry)}`;
    unique.set(key, candidate);
  }
  return [...unique.values()];
}

export function listCatalogFacetNames(catalog: BasesCatalog): string[] {
  const candidates = catalogCandidates(catalog);
  const pathsByName = new Map<string, Set<string>>();
  for (const candidate of candidates) {
    const definitions = pathsByName.get(candidate.name) ?? new Set<string>();
    definitions.add(JSON.stringify(candidate.entry));
    pathsByName.set(candidate.name, definitions);
  }
  return [...pathsByName]
    .filter(([, paths]) => paths.size === 1)
    .map(([name]) => name)
    .sort((left, right) => left.localeCompare(right));
}

export function listAvailableCatalogFacetNames(
  catalog: BasesCatalog,
  registeredFacetNames: Iterable<string>,
): string[] {
  const registered = new Set(registeredFacetNames);
  return listCatalogFacetNames(catalog).filter((name) => !registered.has(name));
}

/** Contract suffix of a `path.sol:ContractName` reference, or null when the value carries none. */
export function contractReferenceName(contract: string): string | null {
  const match = contract.match(/:([A-Za-z_$][A-Za-z0-9_$]*)$/);
  return match?.[1] ?? null;
}

function projectRelativePath(projectRoot: string, sourcePath: string): string {
  const relative = path.relative(projectRoot, sourcePath);
  if (
    !relative ||
    relative === "." ||
    relative === ".." ||
    relative.startsWith(`..${path.sep}`) ||
    path.isAbsolute(relative)
  ) {
    throw new Error(`Facet source must be inside the Compose project: ${sourcePath}`);
  }
  return toPosixPath(relative);
}

function registrationFromCatalog(candidate: CatalogCandidate): ResolvedFacetInstall {
  const { name, entry, group } = candidate;
  const contractName = contractNameFromSourcePath(entry.path);
  if (isComposePackagePath(entry.path)) {
    return {
      name,
      contractName,
      targetGroup: group,
      registration: {
        source: "package",
        contract: contractName,
        package: parsePackageName(entry.path),
        ...(entry.mod ? { mod: entry.mod } : {}),
        constructor: entry.constructor,
        ...(entry.erc165 ? { erc165: entry.erc165 } : {}),
      },
    };
  }

  return {
    name,
    contractName,
    targetGroup: group,
    catalogSource: resolveCatalogSourceForRead(entry.path),
    registration: {
      source: "local",
      // Set to the project-relative path once the catalog file has been copied.
      contract: "",
      ...(entry.mod ? { mod: entry.mod } : {}),
      constructor: entry.constructor,
      ...(entry.erc165 ? { erc165: entry.erc165 } : {}),
    },
  };
}

export async function resolveFacetInstallReference(
  reference: string | FacetInstallReference,
  catalog: BasesCatalog,
  projectRoot: string,
  options?: FacetReferenceResolutionOptions,
): Promise<ResolvedFacetInstall> {
  if (typeof reference === "string") {
    const catalogMatches = catalogCandidates(catalog).filter((candidate) => candidate.name === reference);
    if (catalogMatches.length === 1) return registrationFromCatalog(catalogMatches[0]);
    if (catalogMatches.length > 1) {
      const candidates = catalogMatches.map((candidate) => candidate.entry.path).join("\n  ");
      throw new Error(`Facet name '${reference}' is ambiguous. Use a source path or manifest reference:\n  ${candidates}`);
    }

    const contractName = contractReferenceName(reference);
    if (contractName) {
      return resolveLocalReference(reference, contractName, projectRoot);
    }

    const matched = await resolveFuzzyLocalReference(reference, projectRoot, options);
    if (matched) return matched;
    throw new Error(
      `Unknown catalog facet '${reference}'. Use a catalog name, path.sol:ContractName, or the name of a contract in this project.`,
    );
  }

  if (!reference.source) {
    const matches = catalogCandidates(catalog).filter((candidate) => candidate.name === reference.name);
    if (matches.length === 1) return registrationFromCatalog(matches[0]);
    if (matches.length > 1) {
      throw new Error(`Facet name '${reference.name}' is ambiguous; specify its source in the manifest.`);
    }
    const matched = await resolveFuzzyLocalReference(reference.name, projectRoot, options);
    if (matched) return matched;
    throw new Error(`Unknown catalog facet '${reference.name}'. Add a local or package source to the manifest.`);
  }

  if (reference.source === "local") {
    const contractName = contractReferenceName(reference.contract);
    if (!contractName) {
      throw new Error(`Local facet '${reference.name}' must use path.sol:ContractName.`);
    }
    if (contractName !== reference.name) {
      throw new Error(`Local facet key '${reference.name}' must match contract '${contractName}'.`);
    }
    return resolveLocalReference(reference.contract, contractName, projectRoot, reference.name);
  }

  const contractName = reference.contract.includes(":")
    ? contractReferenceName(reference.contract)
    : reference.contract;
  if (!contractName || !reference.package.trim()) {
    throw new Error(`Package facet '${reference.name}' must define a package and contract.`);
  }
  if (contractName !== reference.name) {
    throw new Error(`Package facet key '${reference.name}' must match contract '${contractName}'.`);
  }
  const registration: FacetRegistration = {
    source: "package",
    contract: contractName,
    package: reference.package,
    constructor: undefined,
  };
  return {
    name: reference.name,
    contractName,
    registration,
  };
}

async function resolveLocalReference(
  reference: string,
  contractName: string,
  projectRoot: string,
  facetName = contractName,
): Promise<ResolvedFacetInstall> {
  const separator = reference.lastIndexOf(":");
  const source = reference.slice(0, separator);
  const absolutePath = path.resolve(projectRoot, source);
  await fs.access(absolutePath).catch(() => {
    throw new Error(`Facet source not found: ${source}`);
  });
  const registration: FacetRegistration = {
    source: "local",
    contract: `${projectRelativePath(projectRoot, absolutePath)}:${contractName}`,
    constructor: undefined,
  };
  return {
    name: facetName,
    contractName,
    registration,
  };
}

/**
 * Lists every Solidity source in the project that can back a bare facet
 * reference, skipping dependency and generated directories.
 *
 * @param projectRoot - The Compose project root to scan.
 * @returns Project-relative POSIX paths of `.sol` files, in directory order.
 */
async function listProjectSoliditySources(projectRoot: string): Promise<string[]> {
  const sources: string[] = [];

  const walk = async (directory: string): Promise<void> => {
    const entries = await fs.readdir(directory, { withFileTypes: true });
    for (const entry of entries) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        if (entry.name.startsWith(".") || IGNORED_SOURCE_DIRECTORIES.has(entry.name)) continue;
        await walk(target);
      } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".sol")) {
        sources.push(toPosixPath(path.relative(projectRoot, target)));
      }
    }
  };

  await walk(projectRoot);
  return sources;
}

/** Returns the contract, library, and interface names declared by a source. */
function declaredContractNames(source: string): string[] {
  const names: string[] = [];
  const pattern = new RegExp(CONTRACT_DECLARATION, "g");
  for (const match of removeSolidityComments(source).matchAll(pattern)) {
    if (match[1]) names.push(match[1]);
  }
  return names;
}

/**
 * Picks the contract name to register for a matched source: a declared name
 * equal to the reference wins, then a declared name equal to the file name,
 * then the file name itself.
 */
function contractNameForMatch(source: string, declared: string[], reference: string): string {
  const lowerReference = reference.toLowerCase();
  const fileName = path.basename(source, path.extname(source));
  return (
    declared.find((name) => name.toLowerCase() === lowerReference) ??
    declared.find((name) => name.toLowerCase() === fileName.toLowerCase()) ??
    fileName
  );
}

/**
 * Fuzzy-matches a bare facet reference against the project's Solidity sources.
 *
 * Match tiers, in order: file name equality, declared contract name equality,
 * then substring containment in either direction. Only the best non-empty tier
 * is returned.
 *
 * @param reference - A bare facet/contract name with no `path.sol:` prefix.
 * @param projectRoot - The Compose project root to scan.
 * @returns Matching sources, best tier first.
 */
export async function findLocalContractMatches(
  reference: string,
  projectRoot: string,
): Promise<LocalContractMatch[]> {
  const sources = await listProjectSoliditySources(projectRoot);
  const lowerReference = reference.toLowerCase();

  const fileNameMatches = sources.filter(
    (source) => path.basename(source, path.extname(source)).toLowerCase() === lowerReference,
  );
  if (fileNameMatches.length > 0) {
    return Promise.all(fileNameMatches.map(async (source) => ({
      source,
      contractName: contractNameForMatch(
        source,
        declaredContractNames(await fs.readFile(path.join(projectRoot, source), "utf8")),
        reference,
      ),
    })));
  }

  const scanned = await Promise.all(sources.map(async (source) => ({
    source,
    declared: declaredContractNames(await fs.readFile(path.join(projectRoot, source), "utf8")),
  })));

  const declaredExact = scanned
    .filter((file) => file.declared.some((name) => name.toLowerCase() === lowerReference))
    .map((file) => ({
      source: file.source,
      contractName: contractNameForMatch(file.source, file.declared, reference),
    }));
  if (declaredExact.length > 0) return declaredExact;

  const fuzzy: LocalContractMatch[] = [];
  for (const file of scanned) {
    const fileName = path.basename(file.source, path.extname(file.source));
    const contains = (candidate: string): boolean =>
      candidate.toLowerCase().includes(lowerReference) || lowerReference.includes(candidate.toLowerCase());
    const declaredHit = file.declared.find(contains);
    if (declaredHit) {
      fuzzy.push({ source: file.source, contractName: declaredHit });
    } else if (contains(fileName)) {
      fuzzy.push({ source: file.source, contractName: contractNameForMatch(file.source, file.declared, reference) });
    }
  }
  return fuzzy;
}

/**
 * Resolves a bare facet reference to the project source it names, prompting
 * (or failing with the candidate list) when several sources match.
 *
 * @param reference - A bare facet/contract name with no `path.sol:` prefix.
 * @param projectRoot - The Compose project root to scan.
 * @param options - Optional ambiguity resolution hooks.
 * @returns The resolved facet, or `null` when no project source matches.
 */
async function resolveFuzzyLocalReference(
  reference: string,
  projectRoot: string,
  options?: FacetReferenceResolutionOptions,
): Promise<ResolvedFacetInstall | null> {
  const matches = await findLocalContractMatches(reference, projectRoot);
  if (matches.length === 0) return null;

  let chosen = matches[0];
  if (matches.length > 1) {
    const sources = matches.map((match) => match.source);
    const selected = options?.selectLocalMatch
      ? await options.selectLocalMatch(sources)
      : undefined;
    const picked = matches.find((match) => match.source === selected);
    if (!picked) {
      throw new Error(
        `Facet '${reference}' matches several project sources:\n  ${sources.join("\n  ")}\nUse path.sol:ContractName to choose one.`,
      );
    }
    chosen = picked;
  }

  return resolveLocalReference(`${chosen.source}:${chosen.contractName}`, chosen.contractName, projectRoot);
}

export function withCatalogCopyTarget(
  facet: ResolvedFacetInstall,
  projectRoot: string,
  contractSourceRoot: string,
  copiedSourcePath: string,
): ResolvedFacetInstall {
  if (!facet.catalogSource) return facet;
  const sourcePath = path.resolve(copiedSourcePath);
  const targetName = path.basename(sourcePath, path.extname(sourcePath));
  const targetPath = path.join(contractSourceRoot, facet.targetGroup ?? "facets", path.basename(sourcePath));
  return {
    ...facet,
    registration: {
      ...facet.registration,
      contract: `${projectRelativePath(projectRoot, targetPath)}:${facet.contractName ?? targetName}`,
    },
  };
}

export async function copyCatalogFacetSources(
  facets: ResolvedFacetInstall[],
  projectRoot: string,
  contractSourceRoot: string,
): Promise<{ facets: ResolvedFacetInstall[]; createdFiles: string[] }> {
  const localCatalogFacets = facets.filter((facet) => facet.catalogSource);
  if (localCatalogFacets.length === 0) return { facets, createdFiles: [] };

  const seeds = localCatalogFacets.map((facet) => ({
    source: path.resolve(facet.catalogSource as string),
    target: path.join(
      contractSourceRoot,
      facet.targetGroup ?? "facets",
      `${facet.contractName ?? facet.name}.sol`,
    ),
  }));

  const closure = await resolveLocalSolidityImportClosure(seeds.map((seed) => seed.source));
  const copyTargets = new Map<string, string>();
  for (const [source, target] of planImportClosureTargets(seeds, closure, contractSourceRoot)) {
    const existingSource = copyTargets.get(target);
    if (existingSource && existingSource !== source) {
      throw new Error(`Multiple catalog files would be copied to ${target}.`);
    }
    copyTargets.set(target, source);
  }

  for (const [target, source] of copyTargets) {
    try {
      const existingContent = await fs.readFile(target);
      const sourceContent = await fs.readFile(source);
      if (!existingContent.equals(sourceContent)) {
        throw new Error(`Facet source destination already exists with different contents: ${target}`);
      }
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }

  const createdFiles: string[] = [];
  try {
    for (const [target, source] of copyTargets) {
      if (await fs.access(target).then(() => true).catch(() => false)) continue;
      await fs.mkdir(path.dirname(target), { recursive: true });
      await fs.copyFile(source, target, constants.COPYFILE_EXCL);
      createdFiles.push(target);
    }
  } catch (error) {
    await Promise.all(createdFiles.map((filePath) => fs.rm(filePath, { force: true })));
    throw error;
  }

  return {
    facets: facets.map((facet) =>
      facet.catalogSource
        ? withCatalogCopyTarget(
            facet,
            projectRoot,
            contractSourceRoot,
            path.join(
              contractSourceRoot,
              facet.targetGroup ?? "facets",
              `${facet.contractName ?? facet.name}.sol`,
            ),
          )
        : facet,
    ),
    createdFiles,
  };
}
