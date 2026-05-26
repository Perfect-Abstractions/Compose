import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { assertDirectoryEmpty } from "../../scaffold/utils/fileManager.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const require = createRequire(import.meta.url);

const templateConfig = require(resolve(
  __dirname,
  "..",
  "..",
  "config",
  "templates.json"
)) as {
  templates: { id: string; name: string }[];
};

type TemplateChoice = {
  name: string;
  value: string;
};

export function getTemplateChoices(): TemplateChoice[] {
  const list = templateConfig.templates || [];
  if (list.length === 0) {
    return [{ name: "Default", value: "default" }];
  }
  return list.map((t) => ({ name: t.name, value: t.id }));
}

export async function validateProjectLocation(
  input: string
): Promise<boolean | string> {
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
