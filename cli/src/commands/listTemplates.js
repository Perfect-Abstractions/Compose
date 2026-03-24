const { loadTemplateConfig } = require("../scaffold/utils/templateLoader");
const { logger } = require("../utils/logger");

async function runListTemplatesCommand() {
  const config = await loadTemplateConfig();

  config.templates.forEach((template) => {
    logger.plain(`${template.id} - ${template.name}`);
    template.variants.forEach((variant) => {
      const meta = [
        variant.framework,
        variant.language,
        variant.projectType,
      ].filter(Boolean).join(", ");

      logger.plain(`  - ${variant.id}${meta ? ` (${meta})` : ""}`);
    });
  });
}

module.exports = {
  runListTemplatesCommand,
};
