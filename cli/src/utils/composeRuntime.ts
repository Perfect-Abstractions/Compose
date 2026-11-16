import fs from "node:fs/promises";
import path from "node:path";
import { ensureGitignoreEntries } from "./gitignore";

/** Project-relative directory that holds every Compose-owned runtime file. */
export const COMPOSE_DIR = ".compose";

/** Frameworks that can own a Compose runtime directory. */
export type ComposeFramework = "foundry" | "hardhat";

/**
 * Resolves the Compose runtime directory for a framework.
 *
 * @param projectRoot - Absolute project root.
 * @param framework - Framework whose transient files live in the directory.
 * @returns Absolute path of `<projectRoot>/.compose/<framework>`.
 */
export function composeRuntimeDir(
  projectRoot: string,
  framework: ComposeFramework,
): string {
  return path.join(projectRoot, COMPOSE_DIR, framework);
}

/**
 * Ensures the project `.gitignore` ignores the Compose runtime directory.
 *
 * Uses a bare `.compose/` rule so nested workspaces are covered by the same
 * entry that hides the project root's runtime files.
 *
 * @param projectRoot - Absolute project root.
 * @throws {Error} If an existing `.gitignore` cannot be read or written.
 */
export async function ensureComposeDirIgnored(projectRoot: string): Promise<void> {
  const gitignorePath = path.join(projectRoot, ".gitignore");
  let gitignore = "";
  try {
    gitignore = await fs.readFile(gitignorePath, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
  }

  const updated = ensureGitignoreEntries(gitignore, [`${COMPOSE_DIR}/`]);
  if (updated !== gitignore) {
    await fs.writeFile(gitignorePath, updated, "utf8");
  }
}

/**
 * Ensures the runtime directory exists and is ignored by git.
 *
 * @param projectRoot - Absolute project root.
 * @param framework - Framework whose transient files live in the directory.
 * @returns Absolute path of the created runtime directory.
 */
export async function ensureComposeRuntimeDir(
  projectRoot: string,
  framework: ComposeFramework,
): Promise<string> {
  await ensureComposeDirIgnored(projectRoot);
  const runtimeDir = composeRuntimeDir(projectRoot, framework);
  await fs.mkdir(runtimeDir, { recursive: true });
  return runtimeDir;
}
