/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");
const { validateTemplatesConfig } = require("../src/config/validateTemplatesConfig");

const ROOT_DIR = path.resolve(__dirname, "..");
const TEMPLATES_ROOT = path.join(ROOT_DIR, "src", "templates");
const OUTPUT_CONFIG_PATH = path.join(ROOT_DIR, "src", "config", "templates.json");

function readJsonFile(filePath) {
  const content = fs.readFileSync(filePath, "utf8");
  return JSON.parse(content);
}

function parseVariantId(templateId, variantId) {
  const suffix = variantId.startsWith(`${templateId}-`)
    ? variantId.slice(templateId.length + 1)
    : variantId;

  const [framework, ...rest] = suffix.split("-");

  return {
    framework,
    projectType: rest.length > 0 ? rest.join("-") : undefined,
  };
}

function inferLanguageFromPath(relativePath) {
  if (relativePath.includes("/ts/")) {
    return "typescript";
  }

  if (relativePath.includes("/js/")) {
    return "javascript";
  }

  return undefined;
}

function buildVariantPath(templateId, framework, projectType, overridePath) {
  if (overridePath) {
    return overridePath;
  }

  if (framework === "foundry") {
    return `templates/${templateId}/${framework}`;
  }

  if (!projectType) {
    return `templates/${templateId}/${framework}`;
  }

  return `templates/${templateId}/${framework}/ts/${projectType}`;
}

function loadTemplateManifests() {
  const entries = fs.readdirSync(TEMPLATES_ROOT, { withFileTypes: true });
  const templates = [];

  entries.forEach((entry) => {
    if (!entry.isDirectory()) {
      return;
    }

    const templateDir = path.join(TEMPLATES_ROOT, entry.name);
    const manifestPath = path.join(templateDir, "template.json");

    if (!fs.existsSync(manifestPath)) {
      return;
    }

    const manifest = readJsonFile(manifestPath);
    templates.push(manifest);
  });

  return templates;
}

function buildTemplatesConfig() {
  const templateManifests = loadTemplateManifests();

  const templates = templateManifests.map((manifest) => {
    const templateId = manifest.id;

    const variants = (manifest.variants || []).map((variantId) => {
      const { framework, projectType } = parseVariantId(templateId, variantId);

      const pathValue = buildVariantPath(
        templateId,
        framework,
        projectType,
      );

      const language = inferLanguageFromPath(pathValue);

      return {
        id: variantId,
        framework,
        path: pathValue,
        ...(language ? { language } : {}),
        ...(projectType ? { projectType } : {}),
      };
    });

    return {
      id: templateId,
      name: manifest.name,
      description: manifest.description,
      variants,
    };
  });

  const config = {
    templates,
    defaultTemplateId: templateManifests[0] ? templateManifests[0].id : "default",
  };

  validateTemplatesConfig(config);

  return config;
}

function writeTemplatesConfig(config) {
  const json = `${JSON.stringify(config, null, 2)}\n`;
  fs.writeFileSync(OUTPUT_CONFIG_PATH, json, "utf8");
}

function main() {
  try {
    const config = buildTemplatesConfig();
    writeTemplatesConfig(config);
    console.log(`Generated templates config at ${path.relative(ROOT_DIR, OUTPUT_CONFIG_PATH)}`);
  } catch (error) {
    console.error("Failed to generate templates config:");
    console.error(error.message || error);
    process.exitCode = 1;
  }
}

if (require.main === module) {
  main();
}

