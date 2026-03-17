const path = require("node:path");
const fs = require("fs-extra");
const { TEMPLATE_REGISTRY_PATH } = require("../../config/constants");
const { validateTemplatesConfig } = require("../../config/validateTemplatesConfig");

async function loadTemplateConfig() {
  const config = await fs.readJson(TEMPLATE_REGISTRY_PATH);
  validateTemplatesConfig(config);
  return config;
}

function pickVariant(config, options) {
  const { template = config.defaultTemplateId, framework, language, projectType } = options;

  const templateEntry = config.templates.find((item) => item.id === template);
  if (!templateEntry) {
    throw new Error(`Template not found: ${template}`);
  }

  const variant = templateEntry.variants.find((item) => {
    if (framework && item.framework !== framework) {
      return false;
    }
    if (item.framework === "hardhat" && language && item.language !== language) {
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
    throw new Error(`No template variant for template=${template}, framework=${framework}, language=${language || "-"}`);
  }

  return variant;
}

function resolveTemplatePath(variant) {
  return path.join(__dirname, "..", "..", variant.path);
}

module.exports = {
  loadTemplateConfig,
  pickVariant,
  resolveTemplatePath,
};
