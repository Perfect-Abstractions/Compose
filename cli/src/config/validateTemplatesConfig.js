function ensureString(value, keyPath) {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`Invalid templates config: ${keyPath} must be a non-empty string`);
  }
}

function validateTemplatesConfig(config) {
  if (!config || typeof config !== "object") {
    throw new Error("Invalid templates config: config root must be an object");
  }

  if (!Array.isArray(config.templates) || config.templates.length === 0) {
    throw new Error("Invalid templates config: templates must be a non-empty array");
  }

  config.templates.forEach((template, index) => {
    ensureString(template.id, `templates[${index}].id`);
    ensureString(template.name, `templates[${index}].name`);

    if (!Array.isArray(template.variants) || template.variants.length === 0) {
      throw new Error(`Invalid templates config: templates[${index}].variants must be a non-empty array`);
    }

    template.variants.forEach((variant, variantIndex) => {
      ensureString(variant.id, `templates[${index}].variants[${variantIndex}].id`);
      ensureString(variant.framework, `templates[${index}].variants[${variantIndex}].framework`);
      ensureString(variant.path, `templates[${index}].variants[${variantIndex}].path`);
    });
  });

  ensureString(config.defaultTemplateId, "defaultTemplateId");

  return true;
}

module.exports = {
  validateTemplatesConfig,
};
