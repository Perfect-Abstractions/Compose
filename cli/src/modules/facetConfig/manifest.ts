import fs from "node:fs/promises";
import path from "node:path";
import { pathExists } from "../../utils/files";
import type {
  FacetBatch,
  FacetBatchOperation,
  FacetInstallReference,
  InstallFacetBatch,
  RemoveFacetBatch,
} from "./types";

export const FACET_BATCH_DIRECTORY = path.join("compose", "facet-batches");

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasFilePath(value: string): boolean {
  return path.isAbsolute(value) || value.includes("/") || value.includes("\\");
}

function withJsonExtension(value: string): string {
  return path.extname(value) ? value : `${value}.json`;
}

export function resolveFacetBatchPath(projectRoot: string, reference: string): string {
  if (!reference.trim()) throw new Error("Manifest name or path cannot be empty.");
  if (hasFilePath(reference)) return path.resolve(projectRoot, reference);
  return path.resolve(projectRoot, FACET_BATCH_DIRECTORY, withJsonExtension(reference));
}

export async function resolveExistingFacetBatchPath(
  projectRoot: string,
  reference: string,
): Promise<string> {
  const directPath = path.resolve(projectRoot, reference);
  if ((hasFilePath(reference) || path.extname(reference) !== "") && await pathExists(directPath)) return directPath;

  const defaultPath = resolveFacetBatchPath(projectRoot, reference);
  if (await pathExists(defaultPath)) return defaultPath;

  throw new Error(`Facet batch manifest not found: ${reference}`);
}

export function validateFacetBatch(value: unknown, expectedOperation?: FacetBatchOperation): FacetBatch {
  if (!isRecord(value)) throw new Error("Facet batch manifest must be a JSON object.");
  if (value.version !== 1) throw new Error("Unsupported facet batch manifest version; expected version 1.");
  if (value.operation !== "install" && value.operation !== "remove") {
    throw new Error("Facet batch manifest operation must be 'install' or 'remove'.");
  }
  if (expectedOperation && value.operation !== expectedOperation) {
    throw new Error(`This command expects an '${expectedOperation}' manifest, but received '${value.operation}'.`);
  }
  if (!isRecord(value.diamonds) || Object.keys(value.diamonds).length === 0) {
    throw new Error("Facet batch manifest must contain at least one diamond.");
  }

  const diamonds: Record<string, FacetInstallReference[] | string[]> = {};
  for (const [diamondName, facetsValue] of Object.entries(value.diamonds)) {
    if (!diamondName.trim() || !Array.isArray(facetsValue) || facetsValue.length === 0) {
      throw new Error(`Manifest diamond '${diamondName || "<empty>"}' must have a non-empty facet list.`);
    }

    if (value.operation === "remove") {
      const names = facetsValue.map((facet) => {
        if (typeof facet !== "string" || !facet.trim()) {
          throw new Error(`Remove manifest for '${diamondName}' must contain facet names as strings.`);
        }
        return facet.trim();
      });
      if (new Set(names).size !== names.length) {
        throw new Error(`Remove manifest for '${diamondName}' contains duplicate facet names.`);
      }
      diamonds[diamondName] = names;
      continue;
    }

    const references = facetsValue.map((facet) => validateInstallReference(facet, diamondName));
    const names = references.map((reference) => reference.name);
    if (new Set(names).size !== names.length) {
      throw new Error(`Install manifest for '${diamondName}' contains duplicate facet names.`);
    }
    diamonds[diamondName] = references;
  }

  return value.operation === "install"
    ? { version: 1, operation: "install", diamonds: diamonds as Record<string, FacetInstallReference[]> }
    : { version: 1, operation: "remove", diamonds: diamonds as Record<string, string[]> };
}

function validateInstallReference(value: unknown, diamondName: string): FacetInstallReference {
  if (typeof value === "string" && value.trim()) {
    const localReference = value.trim();
    const contract = localReference.match(/^.+:([A-Za-z_$][A-Za-z0-9_$]*)$/)?.[1];
    return contract
      ? { name: contract, source: "local", contract: localReference }
      : { name: localReference };
  }
  if (!isRecord(value) || typeof value.name !== "string" || !value.name.trim()) {
    throw new Error(`Install manifest for '${diamondName}' contains an invalid facet reference.`);
  }

  const name = value.name.trim();
  if (value.source === undefined) return { name };
  if (value.source === "local") {
    if (typeof value.contract !== "string" || !/^.+:([A-Za-z_$][A-Za-z0-9_$]*)$/.test(value.contract.trim())) {
      throw new Error(`Local facet '${name}' must use path.sol:ContractName.`);
    }
    return { name, source: "local", contract: value.contract.trim() };
  }
  if (value.source === "package") {
    if (typeof value.contract !== "string" || !value.contract.trim()) {
      throw new Error(`Package facet '${name}' must define a contract name.`);
    }
    if (typeof value.package !== "string" || !value.package.trim()) {
      throw new Error(`Package facet '${name}' must define its package name.`);
    }
    return {
      name,
      source: "package",
      contract: value.contract.trim(),
      package: value.package.trim(),
    };
  }

  throw new Error(`Facet '${name}' source must be 'local' or 'package'.`);
}

export function createInstallFacetBatch(
  diamonds: InstallFacetBatch["diamonds"],
): InstallFacetBatch {
  return validateFacetBatch({ version: 1, operation: "install", diamonds }, "install") as InstallFacetBatch;
}

export function createRemoveFacetBatch(
  diamonds: RemoveFacetBatch["diamonds"],
): RemoveFacetBatch {
  return validateFacetBatch({ version: 1, operation: "remove", diamonds }, "remove") as RemoveFacetBatch;
}

export async function readFacetBatch(
  filePath: string,
  expectedOperation: FacetBatchOperation,
): Promise<FacetBatch> {
  let value: unknown;
  try {
    value = JSON.parse(await fs.readFile(filePath, "utf8"));
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown JSON parse error";
    throw new Error(`Unable to read facet batch manifest ${filePath}: ${message}`, { cause: error });
  }
  return validateFacetBatch(value, expectedOperation);
}

export function serializeFacetBatch(batch: FacetBatch): string {
  return `${JSON.stringify(batch, null, 2)}\n`;
}
