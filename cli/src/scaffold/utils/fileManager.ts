import fs from "fs-extra";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export async function assertTargetDoesNotExist(
  projectDir: string
): Promise<void> {
  const exists = await fs.pathExists(projectDir);
  if (exists) {
    throw new Error(`Target directory already exists: ${projectDir}`);
  }
}

export async function copyTemplate(
  templateDir: string,
  projectDir: string
): Promise<void> {
  await fs.copy(templateDir, projectDir);
}

export async function readJson(filePath: string): Promise<unknown> {
  return fs.readJson(filePath);
}

export async function writeJson(
  filePath: string,
  data: Record<string, unknown>
): Promise<void> {
  await fs.writeJson(filePath, data, { spaces: 2 });
}

export async function appendLineIfMissing(
  filePath: string,
  line: string
): Promise<void> {
  const exists = await fs.pathExists(filePath);
  if (!exists) {
    await fs.outputFile(filePath, `${line}\n`);
    return;
  }

  const content: string = await fs.readFile(filePath, "utf8");
  if (!content.includes(line)) {
    await fs.writeFile(filePath, `${content.trimEnd()}\n${line}\n`);
  }
}

export async function assertDirectoryEmpty(
  projectDir: string
): Promise<void> {
  const entries = await fs.readdir(projectDir);
  const ignoredEntries = [".git"];
  const nonIgnored = entries.filter(
    (entry) => !ignoredEntries.includes(entry)
  );
  if (nonIgnored.length > 0) {
    throw new Error(`Target directory is not empty: ${projectDir}`);
  }
}

export function resolveProjectDir(projectName: string): string {
  return path.join(process.cwd(), projectName);
}

export function getProjectDisplayName(
  projectName: string,
  projectDir: string
): string {
  if (projectName === ".") {
    return path.basename(projectDir);
  }
  return projectName;
}

export function getTemplateDisplayName(templatePath: string): string {
  const templatesRoot = path.join(__dirname, "..", "..", "templates");
  let templateName = path
    .relative(templatesRoot, templatePath)
    .replace(/\\/g, "/");
  if (templateName.startsWith("..")) {
    templateName = path.basename(templatePath);
  }
  return templateName;
}
