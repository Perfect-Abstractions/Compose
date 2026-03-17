const templateConfig = require("../../config/templates.json");
const { assertDirectoryEmpty } = require("../../scaffold/utils/fileManager");

function getTemplateChoices() {
  const list = templateConfig.templates || [];
  if (list.length === 0) {
    return [{ name: "Default", value: "default" }];
  }
  return list.map((t) => ({ name: t.name, value: t.id }));
}

async function validateProjectLocation(input) {
  if (input !== ".") {
    return true;
  }

  try {
    await assertDirectoryEmpty(process.cwd());
    return true;
  } catch {
    return 'Current directory must be empty (or only .git) when using ".".';
  }
}

module.exports = {
  getTemplateChoices,
  validateProjectLocation,
};

