const path = require("node:path");

const COMPOSE_REPO_URL = "https://github.com/Perfect-Abstractions/Compose";
const COMPOSE_DOCS_URL = "https://compose.diamonds/";

const COMPOSE_NPM_PACKAGE = "@perfect-abstractions/compose";
const COMPOSE_NPM_VERSION = "latest";

const COMPOSE_FOUNDRY_DEP = "Perfect-Abstractions/Compose";

const DEFAULT_TEMPLATE_ID = "default";
const DEFAULT_FRAMEWORK = "foundry";

const TEMPLATE_REGISTRY_PATH = path.join(__dirname, "templates.json");

module.exports = {
  COMPOSE_REPO_URL,
  COMPOSE_DOCS_URL,
  COMPOSE_NPM_PACKAGE,
  COMPOSE_NPM_VERSION,
  COMPOSE_FOUNDRY_DEP,
  DEFAULT_TEMPLATE_ID,
  DEFAULT_FRAMEWORK,
  TEMPLATE_REGISTRY_PATH,
};

