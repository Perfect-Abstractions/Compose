import { loadTemplateConfig } from "../scaffold/utils/templateLoader.js";
import { logger } from "../utils/logger.js";

export async function runListTemplatesCommand(): Promise<void> {
  const config = loadTemplateConfig();

  config.templates.forEach((template) => {
    logger.plain(`${template.id} - ${template.name}`);
    template.variants.forEach((variant) => {
      const meta = [variant.framework, variant.language, variant.projectType]
        .filter(Boolean)
        .join(", ");

      logger.plain(`  - ${variant.id}${meta ? ` (${meta})` : ""}`);
    });
  });
}
