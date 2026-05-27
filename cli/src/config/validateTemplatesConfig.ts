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

function ensureString(value: unknown, keyPath: string): asserts value is string {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(
      `Invalid templates config: ${keyPath} must be a non-empty string`
    );
  }
}

export function validateTemplatesConfig(config: unknown): config is TemplatesConfig {
  if (!config || typeof config !== "object") {
    throw new Error("Invalid templates config: config root must be an object");
  }

  const cfg = config as TemplatesConfig;

  if (!Array.isArray(cfg.templates) || cfg.templates.length === 0) {
    throw new Error(
      "Invalid templates config: templates must be a non-empty array"
    );
  }

  cfg.templates.forEach((template, index) => {
    ensureString(template.id, `templates[${index}].id`);
    ensureString(template.name, `templates[${index}].name`);

    if (
      !Array.isArray(template.variants) ||
      template.variants.length === 0
    ) {
      throw new Error(
        `Invalid templates config: templates[${index}].variants must be a non-empty array`
      );
    }

    template.variants.forEach((variant, variantIndex) => {
      ensureString(variant.id, `templates[${index}].variants[${variantIndex}].id`);
      ensureString(
        variant.framework,
        `templates[${index}].variants[${variantIndex}].framework`
      );
      ensureString(
        variant.path,
        `templates[${index}].variants[${variantIndex}].path`
      );
    });
  });

  ensureString(cfg.defaultTemplateId, "defaultTemplateId");

  return true;
}
