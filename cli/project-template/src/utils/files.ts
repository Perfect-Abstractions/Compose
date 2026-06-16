import fs from "node:fs/promises";
import path from "node:path";
import { parseSolidityImports } from "./solidityText";

// Check whether a filesystem path exists without throwing to callers.
export async function pathExists(target: string): Promise<boolean> {
  try {
    await fs.access(target);
    return true;
  } catch {
    return false;
  }
}

// Copy a file only when the destination does not already exist.
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

// Write text content only when the target file does not already exist.
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

// Resolve local Solidity imports reachable from a set of seed source files.
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
