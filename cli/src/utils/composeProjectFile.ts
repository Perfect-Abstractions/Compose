import fs from "node:fs/promises";
import path from "node:path";
import { findFileAncestor } from "./files";

export type ComposeProjectFile = {
  path: string;
  root: string;
};

export type LoadedComposeProjectFile = ComposeProjectFile & {
  composeJson: unknown;
};

/** Finds the nearest compose.json and returns its path and containing project root. */
export async function locateComposeProjectFile(
  startDirectory: string,
): Promise<ComposeProjectFile | null> {
  const composeJsonPath = await findFileAncestor(path.resolve(startDirectory), "compose.json");
  return composeJsonPath
    ? { path: composeJsonPath, root: path.dirname(composeJsonPath) }
    : null;
}

/** Reads and parses compose.json without applying a module-specific schema. */
export async function readComposeProjectFile(filePath: string): Promise<unknown> {
  return JSON.parse(await fs.readFile(filePath, "utf8")) as unknown;
}

/**
 * Finds, reads, and parses the nearest compose.json.
 *
 * Returns null when no file exists so callers can keep command-specific
 * guidance. Parse errors propagate unchanged; schema validation stays with the
 * caller.
 */
export async function loadComposeProjectFile(
  startDirectory: string,
): Promise<LoadedComposeProjectFile | null> {
  const composeFile = await locateComposeProjectFile(startDirectory);
  if (!composeFile) return null;

  return {
    ...composeFile,
    composeJson: await readComposeProjectFile(composeFile.path),
  };
}
