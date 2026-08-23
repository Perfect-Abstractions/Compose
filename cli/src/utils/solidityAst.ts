import fs from "node:fs/promises";
import path from "node:path";
import {
  SolidityAstSource,
  SoliditySourceUnitAst,
} from "../adapters/interface/IFrameworkAdapter";

/** Recursively lists JSON files below an adapter output directory. */
export async function listJsonFiles(root: string): Promise<string[]> {
  let entries;

  try {
    entries = await fs.readdir(root, { withFileTypes: true });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      return [];
    }
    throw error;
  }

  const nestedFiles = await Promise.all(
    entries.map(async (entry) => {
      const entryPath = path.join(root, entry.name);
      if (entry.isDirectory()) {
        return listJsonFiles(entryPath);
      }
      return entry.isFile() && entry.name.endsWith(".json") ? [entryPath] : [];
    }),
  );

  return nestedFiles.flat().sort();
}

/** Returns true when a compiler JSON value is a Solidity source unit AST. */
export function isSourceUnitAst(value: unknown): value is SoliditySourceUnitAst {
  if (!value || typeof value !== "object") {
    return false;
  }

  const candidate = value as Record<string, unknown>;
  return (
    candidate.nodeType === "SourceUnit" &&
    typeof candidate.id === "number" &&
    typeof candidate.src === "string"
  );
}

/** Deduplicates source units by compiler source name and returns stable ordering. */
export function uniqueAstSources(sources: SolidityAstSource[]): SolidityAstSource[] {
  const unique = new Map<string, SolidityAstSource>();

  for (const source of sources) {
    if (!unique.has(source.sourceName)) {
      unique.set(source.sourceName, source);
    }
  }

  return [...unique.values()].sort((a, b) => a.sourceName.localeCompare(b.sourceName));
}
