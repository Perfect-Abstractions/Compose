import { assertDirectoryEmpty } from "../../scaffold/utils/fileManager.js";
import templateConfig from "../../config/templates.json" with { type: "json" };

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
