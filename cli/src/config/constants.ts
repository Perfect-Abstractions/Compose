import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const COMPOSE_REPO_URL =
  "https://github.com/Perfect-Abstractions/Compose";
export const COMPOSE_DOCS_URL = "https://compose.diamonds/";

export const COMPOSE_NPM_PACKAGE = "@perfect-abstractions/compose";
export const COMPOSE_NPM_VERSION = "latest";

export const COMPOSE_FOUNDRY_DEP = "Perfect-Abstractions/Compose";

export const DEFAULT_TEMPLATE_ID = "default";
export const DEFAULT_FRAMEWORK = "foundry";

export const TEMPLATE_REGISTRY_PATH = resolve(__dirname, "templates.json");
