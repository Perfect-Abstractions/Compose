import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import fs from "node:fs";
import path from "node:path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const require = createRequire(import.meta.url);

const { validateTemplatesConfig } = require(resolve(
  __dirname,
  "..",
  "src",
  "config",
  "validateTemplatesConfig.js"
)) as { validateTemplatesConfig: (config: unknown) => boolean };

const ROOT_DIR = resolve(__dirname, "..");
const TEMPLATES_ROOT = path.join(ROOT_DIR, "src", "templates");
const OUTPUT_CONFIG_PATH = path.join(
  ROOT_DIR,
  "src",
  "config",
  "templates.json"
);

type TemplateManifest = {
  id: string;
  name: string;
  description?: string;
  variants: string[];
};

type VariantEntry = {
  id: string;
  framework: string;
  path: string;
  language?: string;
  projectType?: string;
};

type TemplateEntry = {
  id: string;
  name: string;
  description?: string;
  variants: VariantEntry[];
};

type TemplatesConfig = {
  templates: TemplateEntry[];
  defaultTemplateId: string;
};

function parseVariantId(templateId: string, variantId: string) {
  const suffix = variantId.startsWith(`${templateId}-`)
    ? variantId.slice(templateId.length + 1)
    : variantId;

  const [framework, ...rest] = suffix.split("-");

  return {
    framework,
    projectType: rest.length > 0 ? rest.join("-") : undefined,
  };
}

function inferLanguageFromPath(relativePath: string) {
  if (relativePath.includes("/ts/")) {
    return "typescript";
  }

  if (relativePath.includes("/js/")) {
    return "javascript";
  }

  return undefined;
}

function buildVariantPath(
  templateId: string,
  framework: string,
  projectType?: string,
  overridePath?: string
) {
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

function loadTemplateManifests(): TemplateManifest[] {
  const entries = fs.readdirSync(TEMPLATES_ROOT, { withFileTypes: true });
  const templates: TemplateManifest[] = [];

  entries.forEach((entry) => {
    if (!entry.isDirectory()) {
      return;
    }

    const templateDir = path.join(TEMPLATES_ROOT, entry.name);
    const manifestPath = path.join(templateDir, "template.json");

    if (!fs.existsSync(manifestPath)) {
      return;
    }

    const content = fs.readFileSync(manifestPath, "utf8");
    const manifest = JSON.parse(content) as TemplateManifest;
    templates.push(manifest);
  });

  return templates;
}

function buildTemplatesConfig(): TemplatesConfig {
  const templateManifests = loadTemplateManifests();

  const templates: TemplateEntry[] = templateManifests.map((manifest) => {
    const templateId = manifest.id;

    const variants: VariantEntry[] = (manifest.variants || []).map(
      (variantId: string) => {
        const { framework, projectType } = parseVariantId(
          templateId,
          variantId
        );

        const pathValue = buildVariantPath(
          templateId,
          framework,
          projectType
        );

        const language = inferLanguageFromPath(pathValue);

        const variant: VariantEntry = {
          id: variantId,
          framework,
          path: pathValue,
        };

        if (language) {
          variant.language = language;
        }
        if (projectType) {
          variant.projectType = projectType;
        }

        return variant;
      }
    );

    return {
      id: templateId,
      name: manifest.name,
      description: manifest.description,
      variants,
    };
  });

  const config: TemplatesConfig = {
    templates,
    defaultTemplateId:
      templateManifests[0] ? templateManifests[0].id : "default",
  };

  validateTemplatesConfig(config);

  return config;
}

function writeTemplatesConfig(config: TemplatesConfig): void {
  const json = `${JSON.stringify(config, null, 2)}\n`;
  fs.writeFileSync(OUTPUT_CONFIG_PATH, json, "utf8");
}

function main(): void {
  try {
    const config = buildTemplatesConfig();
    writeTemplatesConfig(config);
    console.log(
      `Generated templates config at ${path.relative(ROOT_DIR, OUTPUT_CONFIG_PATH)}`
    );
  } catch (error) {
    console.error("Failed to generate templates config:");
    console.error(
      error instanceof Error ? error.message : String(error)
    );
    process.exitCode = 1;
  }
}

main();
