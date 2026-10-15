import fs from "node:fs/promises";
import path from "node:path";
import { findFileAncestor } from "./files";

export type ComposeProjectFile = {
  path: string;
  root: string;
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
