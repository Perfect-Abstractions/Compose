import path from "node:path";
import { pathExists, isDirectoryEmpty } from "../../utils/files";

const INVALID_PROJECT_NAME_CHARS = /[\\/:"*?<>|]/;

const PROJECT_NAME_MAX_LENGTH = 210;

/**
 * Validates a project name string for filesystem safety and naming conventions.
 *
 * Checks for invalid characters, length limits, proper starting characters,
 * and ensures the name follows standard project naming conventions.
 *
 * @param name - The project name to validate.
 * @returns `true` if valid, or an error message string if invalid.
 */
export function validateProjectName(name: string): true | string {
  const trimmed = name.trim();

  if (!trimmed) {
    return "Project name cannot be empty.";
  }

  if (trimmed.length > PROJECT_NAME_MAX_LENGTH) {
    return `Project name must be at most ${PROJECT_NAME_MAX_LENGTH} characters.`;
  }

  if (trimmed.startsWith(".") || trimmed.startsWith("_")) {
    return "Project name must not start with '.' or '_'.";
  }

  if (INVALID_PROJECT_NAME_CHARS.test(trimmed)) {
    return "Project name contains invalid characters (\\ / : * ? \" < > |).";
  }

  if (/\s/.test(trimmed)) {
    return "Project name must not contain spaces.";
  }

  if (!/^[a-zA-Z0-9]/.test(trimmed)) {
    return "Project name must start with a letter or digit.";
  }

  if (!/^[a-zA-Z0-9._-]+$/.test(trimmed)) {
    return "Project name may only contain letters, digits, hyphens, underscores, or dots.";
  }

  return true;
}

/**
 * Validates a project name and checks if the target directory is available.
 *
 * Combines string validation with filesystem checks to ensure the project name
 * is valid and the target directory either doesn't exist or is empty (ignoring .git).
 *
 * @param name - The project name to validate.
 * @param outDir - The output directory where the project will be created.
 * @returns Promise resolving to `true` if valid, or an error message string if invalid.
 */
export async function validateProjectNameWithFolder(name: string, outDir: string): Promise<boolean | string> {
  const stringValidation = validateProjectName(name);
  if (stringValidation !== true) {
    return stringValidation;
  }

  const projectRoot = path.resolve(outDir, name);
  const exists = await pathExists(projectRoot);
  if (exists) {
    const isEmpty = await isDirectoryEmpty(projectRoot, [".git"]);
    if (!isEmpty) {
      return `Target directory is not empty: ${projectRoot}`;
    }
  }

  return true;
}
