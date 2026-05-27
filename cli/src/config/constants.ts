import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __filename = fileURLToPath(import.meta.url);
let _packageRoot: string;

function getPackageRoot(): string {
  if (_packageRoot) return _packageRoot;
  let dir = dirname(__filename);
  while (true) {
    if (existsSync(join(dir, "package.json"))) {
      _packageRoot = dir;
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) throw new Error("Could not find package.json");
    dir = parent;
  }
}

export const COMPOSE_REPO_URL =
  "https://github.com/Perfect-Abstractions/Compose";
export const COMPOSE_DOCS_URL = "https://compose.diamonds/";

export const COMPOSE_NPM_PACKAGE = "@perfect-abstractions/compose";
export const COMPOSE_NPM_VERSION = "latest";

export const COMPOSE_FOUNDRY_DEP = "Perfect-Abstractions/Compose";

export const DEFAULT_TEMPLATE_ID = "default";
export const DEFAULT_FRAMEWORK = "foundry";

export const TEMPLATES_ROOT = join(getPackageRoot(), "src");
