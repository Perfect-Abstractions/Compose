import path from "node:path";
import fs from "fs-extra";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";
import { TEMPLATE_REGISTRY_PATH } from "../../config/constants.js";
import { validateTemplatesConfig } from "../../config/validateTemplatesConfig.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

type TemplateVariant = {
  id: string;
  framework: string;
  path: string;
  language?: string;
  projectType?: string;
};

type Template = {
  id: string;
  name: string;
  description?: string;
  variants: TemplateVariant[];
};

type TemplatesConfig = {
  templates: Template[];
  defaultTemplateId: string;
};

type PickOptions = {
  template?: string;
  framework?: string;
  language?: string;
  projectType?: string;
};

export async function loadTemplateConfig(): Promise<TemplatesConfig> {
  const config = await fs.readJson(TEMPLATE_REGISTRY_PATH);
  validateTemplatesConfig(config);
  return config as TemplatesConfig;
}

export function pickVariant(
  config: TemplatesConfig,
  options: PickOptions
): TemplateVariant {
  const { framework, language, projectType } = options;
  const template = options.template || config.defaultTemplateId;

  const templateEntry = config.templates.find((item) => item.id === template);
  if (!templateEntry) {
    throw new Error(`Template not found: ${template}`);
  }

  const variant = templateEntry.variants.find((item) => {
    if (framework && item.framework !== framework) {
      return false;
    }
    if (
      item.framework === "hardhat" &&
      language &&
      item.language !== language
    ) {
      return false;
    }
    if (projectType && item.projectType && item.projectType !== projectType) {
      return false;
    }
    if (!framework && item.id === config.defaultTemplateId) {
      return true;
    }
    return framework ? true : false;
  });

  if (!variant) {
    throw new Error(
      `No template variant for template=${template}, framework=${framework}, language=${language || "-"}`
    );
  }

  return variant;
}

export function resolveTemplatePath(variant: TemplateVariant): string {
  return path.join(__dirname, "..", "..", variant.path);
}
