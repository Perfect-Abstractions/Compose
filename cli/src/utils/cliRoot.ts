import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Absolute path to the CLI package root.
 *
 * Resolves from this compiled file's location (e.g. `dist/utils/cliRoot.js`)
 * up two levels to the package root, where shipped assets like `bases/` and
 * `src/templates/` live. 
 * 
 * Using this constant ensures the CLI can locate its own assets when installed as a package
 */
export const CLI_ROOT = path.resolve(__dirname, "..", "..");
