import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Absolute path to the CLI package root.
 *
 * Resolves from this compiled file's location to the package root, where shipped
 * assets like `bases/` and `src/templates/` live.
 *
 * Handles both development (src/utils/cliRoot.ts) and bundled (dist/index.js) modes:
 * - Development: __dirname is cli/src/utils/, needs to go up 2 levels to cli/
 * - Bundled: __dirname is cli/dist/, needs to go up 1 level to cli/
 *
 * Using this constant ensures the CLI can locate its own assets when installed as a package
 */
function resolveCliRoot(): string {
  const currentDir = __dirname;
  
  // Check if we're in bundled mode (dist/) or development mode (src/utils/)
  const pathParts = currentDir.split(path.sep);
  const isInDist = pathParts[pathParts.length - 1] === "dist";
  
  // If in dist/, go up 1 level; if in src/utils/, go up 2 levels
  return isInDist
    ? path.resolve(currentDir, "..")
    : path.resolve(currentDir, "..", "..");
}

export const CLI_ROOT = resolveCliRoot();
