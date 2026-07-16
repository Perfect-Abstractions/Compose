import fs from "node:fs/promises";
import path from "node:path";
import { CLI_ROOT } from "./cliRoot";

/**
 * Loads a template file from the templates directory.
 *
 * @param subdir - The template subdirectory (e.g. "diamond", "deploy").
 * @param name - The template file name (e.g. "diamond.sol").
 * @returns The template content as a string.
 */
export async function loadTemplate(subdir: string, name: string): Promise<string> {
  const templatePath = path.resolve(CLI_ROOT, "src/templates", subdir, name);
  return fs.readFile(templatePath, "utf8");
}
