import path from "node:path";
import { CLI_ROOT } from "./cliRoot";

/** Prefix used to identify Compose package imports. */
export const COMPOSE_PACKAGE_PREFIX = "@perfect-abstractions/compose/";
const LOCAL_TEMPLATE_PREFIX = "./src/templates/";

/**
 * Resolves the installed root directory of the `@perfect-abstractions/compose`
 * package using Node module resolution.
 *
 * This correctly handles monorepo workspaces where npm may hoist the
 * dependency to the root `node_modules/` instead of the CLI's own
 * `node_modules/`. It also works for global installs and any other
 * layout where the CLI's dependencies are resolved by Node.
 */
function getComposePackageRoot(): string {
  const pkgJson = require.resolve("@perfect-abstractions/compose/package.json");
  return path.dirname(pkgJson);
}

/**
 * Identifies catalog paths that should resolve through the installed Compose package.
 *
 * @param sourcePath - The catalog source path to test.
 * @returns `true` if the path starts with the Compose package prefix.
 */
export function isComposePackagePath(sourcePath: string): boolean {
  return sourcePath.startsWith(COMPOSE_PACKAGE_PREFIX);
}

/**
 * Returns the path segment inside the Compose package for package imports.
 *
 * @param sourcePath - A Compose package path (must start with {@link COMPOSE_PACKAGE_PREFIX}).
 * @returns The subpath after the package prefix.
 * @throws {Error} If the path is not a Compose package path.
 */
export function composePackageSubpath(sourcePath: string): string {
  if (!isComposePackagePath(sourcePath)) {
    throw new Error(`Not a Compose package path: ${sourcePath}`);
  }

  return sourcePath.slice(COMPOSE_PACKAGE_PREFIX.length);
}

/**
 * Converts old local template paths to Compose package imports while preserving local examples.
 *
 * @param sourcePath - The catalog source path to convert.
 * @returns The converted path (package import or unchanged local path).
 */
export function toComposePackagePath(sourcePath: string): string {
  if (!sourcePath.startsWith(LOCAL_TEMPLATE_PREFIX)) {
    return sourcePath;
  }

  return `${COMPOSE_PACKAGE_PREFIX}${sourcePath.slice(LOCAL_TEMPLATE_PREFIX.length)}`;
}

/**
 * Resolves a catalog Solidity path to a local file the CLI can read for validation.
 * Package paths resolve via Node module resolution from the CLI's installed
 * `@perfect-abstractions/compose` dependency.
 * Local paths resolve from the CLI's `src/templates/` directory.
 *
 * @param sourcePath - The catalog source path to resolve.
 * @returns The absolute file path on disk.
 */
export function resolveCatalogSourceForRead(sourcePath: string): string {
  if (isComposePackagePath(sourcePath)) {
    return path.join(getComposePackageRoot(), composePackageSubpath(sourcePath));
  }

  return path.resolve(CLI_ROOT, sourcePath);
}

/**
 * Returns the Solidity contract name implied by a catalog source path.
 *
 * @param sourcePath - The source file path (e.g., `contracts/Foo.sol`).
 * @returns The filename without its extension.
 */
export function contractNameFromSourcePath(sourcePath: string): string {
  return path.basename(sourcePath, path.extname(sourcePath));
}
