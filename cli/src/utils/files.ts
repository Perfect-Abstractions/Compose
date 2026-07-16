import fs from "node:fs/promises";
import path from "node:path";
import { parseSolidityImports } from "./solidityText";

/**
 * Checks whether a filesystem path exists without throwing.
 *
 * @param target - The filesystem path to check.
 * @returns `true` if the path is accessible, `false` otherwise.
 */
export async function pathExists(target: string): Promise<boolean> {
  try {
    await fs.access(target);
    return true;
  } catch {
    return false;
  }
}

/**
 * Returns every file path that cannot be accessed, preserving input order.
 *
 * @param filePaths - An iterable of file paths to check.
 * @returns A Promise resolving to an array of paths that do not exist.
 */
export async function findMissingFiles(filePaths: Iterable<string>): Promise<string[]> {
  const paths = [...filePaths];
  const exists = await Promise.all(paths.map((filePath) => pathExists(filePath)));
  return paths.filter((_, index) => !exists[index]);
}

/**
 * Copies a file only when the destination does not already exist.
 * Creates any intermediate directories as needed.
 *
 * @param from - The source file path to copy from.
 * @param to - The destination file path to copy to.
 */
export async function copyFileIfMissing(from: string, to: string): Promise<void> {
  try {
    await fs.access(to);
    return;
  } catch {
    // destination does not exist, continue
  }
  await fs.mkdir(path.dirname(to), { recursive: true });
  await fs.copyFile(from, to);
}

/**
 * Writes text content only when the target file does not already exist.
 * Creates any intermediate directories as needed.
 *
 * @param to - The destination file path to write to.
 * @param content - The text content to write.
 */
export async function writeFileIfMissing(to: string, content: string): Promise<void> {
  try {
    await fs.access(to);
    return;
  } catch {
    // destination does not exist, continue
  }
  await fs.mkdir(path.dirname(to), { recursive: true });
  await fs.writeFile(to, content, "utf8");
}

/**
 * Converts a platform-specific path to POSIX format using forward slashes.
 *
 * @param value - The file system path to convert.
 * @returns The path with all backslashes replaced by forward slashes.
 */
export function toPosixPath(value: string): string {
  return value.replace(/\\/g, "/");
}

/**
 * Converts a relative path to an import path format.
 * Ensures the path uses forward slashes and starts with "./" if it doesn't already.
 *
 * @param relativePath - The relative path to convert.
 * @returns The path in import format (e.g., "./path/to/file").
 */
export function toRelativeImport(relativePath: string): string {
  const posixPath = toPosixPath(relativePath);
  return posixPath.startsWith(".") ? posixPath : `./${posixPath}`;
}

/**
 * Checks whether a directory is empty, optionally ignoring specific entries.
 *
 * @param dirPath - The directory path to check.
 * @param ignoredEntries - Array of entry names to ignore (e.g., [".git"]).
 * @returns True if the directory is empty after filtering ignored entries.
 */
export async function isDirectoryEmpty(dirPath: string, ignoredEntries: string[] = []): Promise<boolean> {
  const entries = await fs.readdir(dirPath);
  const nonIgnored = entries.filter((entry) => !ignoredEntries.includes(entry));
  return nonIgnored.length === 0;
}

/**
 * Searches for a file by walking up the directory tree from the given start path.
 *
 * @param startDir - The directory to start searching from.
 * @param fileName - The name of the file to find (e.g., "compose.json").
 * @returns The full path to the file, or null if not found.
 */
export async function findFileAncestor(startDir: string, fileName: string): Promise<string | null> {
  let currentDir = startDir;
  const root = path.parse(currentDir).root;

  while (currentDir !== root) {
    const candidate = path.join(currentDir, fileName);
    try {
      await fs.access(candidate);
      return candidate;
    } catch {
      // Not found, continue up
    }
    currentDir = path.dirname(currentDir);
  }

  const rootCandidate = path.join(root, fileName);
  try {
    await fs.access(rootCandidate);
    return rootCandidate;
  } catch {
    return null;
  }
}

/**
 * Extracts the package name from an import path.
 * Handles both scoped packages (@scope/package) and regular packages.
 *
 * @param importPath - The import path (e.g., "@scope/package/subpath" or "package/subpath").
 * @returns The package name (e.g., "@scope/package" or "package").
 */
export function parsePackageName(importPath: string): string {
  const parts = importPath.split("/");
  if (parts[0].startsWith("@")) {
    return parts.slice(0, 2).join("/");
  }
  return parts[0];
}

/**
 * Resolves the transitive closure of local Solidity imports reachable from a set of seed source files.
 * Follows relative imports (`./` or `../`) recursively, skipping already-visited files.
 *
 * @param seedSources - An array of Solidity source file paths to start traversal from.
 * @returns A Promise resolving to a `Set` of all resolved local file paths.
 */
export async function resolveLocalSolidityImportClosure(seedSources: string[]): Promise<Set<string>> {
  const visited = new Set<string>();
  const stack = [...seedSources];

  while (stack.length > 0) {
    const file = path.resolve(stack.pop() as string);
    if (visited.has(file)) continue;
    visited.add(file);

    const code = await fs.readFile(file, "utf8");
    for (const specifier of parseSolidityImports(code)) {
      if (!specifier.startsWith(".")) {
        continue;
      }
      const dep = path.resolve(path.dirname(file), specifier);
      if (!visited.has(dep)) {
        stack.push(dep);
      }
    }
  }

  return visited;
}
