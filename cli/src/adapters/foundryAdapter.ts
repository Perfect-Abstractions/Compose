import fs from "node:fs/promises";
import path from "node:path";
import { ComposeContext } from "../context/types";
import {
  ConfigOptions,
  IFrameworkAdapter,
  SolidityAstSource,
} from "./interface/IFrameworkAdapter";
import { writeFileIfMissing } from "../utils/files";
import { runCommand } from "../utils/exec";
import {
  composePackageSubpath,
  isComposePackagePath,
} from "../utils/soliditySources";
import { CLI_ROOT } from "../utils/cliRoot";
import { isSourceUnitAst, listJsonFiles, uniqueAstSources } from "../utils/solidityAst";

function ensureTomlSectionSettings(
  content: string,
  section: string,
  settings: Record<string, string>,
): string {
  const lines = content.replace(/\r\n/g, "\n").split("\n");
  if (lines.at(-1) === "") lines.pop();

  let sectionIndex = lines.findIndex((line) => line.trim() === `[${section}]`);
  if (sectionIndex === -1) {
    if (lines.length > 0 && lines.at(-1)?.trim() !== "") lines.push("");
    sectionIndex = lines.length;
    lines.push(`[${section}]`);
  }

  let sectionEnd = lines.findIndex(
    (line, index) => index > sectionIndex && /^\s*\[[^\]]+\]\s*$/.test(line),
  );
  if (sectionEnd === -1) sectionEnd = lines.length;

  const sectionLines = lines.slice(sectionIndex + 1, sectionEnd);
  const missingSettings = Object.entries(settings)
    .filter(([key]) => !sectionLines.some((line) => new RegExp(`^\\s*${key}\\s*=`).test(line)))
    .map(([key, value]) => `${key} = ${value}`);

  lines.splice(sectionEnd, 0, ...missingSettings);
  return `${lines.join("\n")}\n`;
}

/** Framework adapter for Foundry-based Diamond projects. */
const adapter: IFrameworkAdapter = {
  getContractSourceRoot(projectRoot: string): string {
    return path.join(projectRoot, "src");
  },

  getScriptRoot(projectRoot: string): string {
    return path.join(projectRoot, "script");
  },

  getTestRoot(projectRoot: string): string {
    return path.join(projectRoot, "test");
  },

  getArtifactDir(projectRoot: string): string {
    return path.join(projectRoot, "out");
  },

  async compile(projectRoot: string): Promise<void> {
    await runCommand("forge", ["build"], { cwd: projectRoot });
  },

  async resolveSoliditySourcePath(ctx: ComposeContext, sourcePath: string): Promise<string> {
    if (path.isAbsolute(sourcePath)) return sourcePath;

    const root = String(ctx.param.projectRoot ?? "");
    if (isComposePackagePath(sourcePath)) {
      return path.join(root, "lib", "Compose", "src", composePackageSubpath(sourcePath));
    }

    return path.resolve(root, sourcePath);
  },

  async compileAst(ctx: ComposeContext, sourcePaths: string[]): Promise<SolidityAstSource[]> {
    const root = String(ctx.param.projectRoot ?? "");
    const buildPaths = sourcePaths.map((sourcePath) => {
      const relativePath = path.relative(root, sourcePath);
      return relativePath && !relativePath.startsWith("..") && !path.isAbsolute(relativePath)
        ? relativePath.replace(/\\/g, "/")
        : sourcePath;
    });
    await runCommand("forge", ["build", ...buildPaths, "--ast", "--force"], { cwd: root });

    const sources: SolidityAstSource[] = [];
    const artifactPaths = await listJsonFiles(path.join(root, "out"));

    for (const artifactPath of artifactPaths) {
      const artifact = JSON.parse(await fs.readFile(artifactPath, "utf8")) as {
        ast?: unknown;
      };
      if (!isSourceUnitAst(artifact.ast)) continue;

      const sourceName = artifact.ast.absolutePath ?? path.basename(path.dirname(artifactPath));
      sources.push({ sourceName, ast: artifact.ast });
    }

    const uniqueSources = uniqueAstSources(sources);
    if (uniqueSources.length === 0) {
      throw new Error("Foundry compilation did not produce any Solidity AST source units.");
    }

    return uniqueSources;
  },

  async initProject(ctx: ComposeContext): Promise<void> {
    const root = String(ctx.param.projectRoot ?? "");
    const installDeps = ctx.param.installDeps !== false;

    await runCommand("forge", ["init", "."], { cwd: root });

    if (installDeps) {
      await runCommand("forge", ["install", "Perfect-Abstractions/Compose"], { cwd: root });
    } else {
      await fs.mkdir(path.join(root, "lib"), { recursive: true });
    }

    await Promise.all([
      fs.rm(path.join(root, "src"), { recursive: true, force: true }),
      fs.rm(path.join(root, "test"), { recursive: true, force: true }),
      fs.rm(path.join(root, "script"), { recursive: true, force: true }),
    ]);

    await fs.mkdir(path.join(root, "test"), { recursive: true });
    await fs.mkdir(path.join(root, "script"), { recursive: true });
  },

  async writeConfig(ctx: ComposeContext, opts: ConfigOptions): Promise<void> {
    const root = String(ctx.param.projectRoot ?? "");

    const foundryTomlPath = path.join(root, "foundry.toml");
    let foundryToml = "";
    try {
      foundryToml = await fs.readFile(foundryTomlPath, "utf8");
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }

    const updatedFoundryToml = ensureTomlSectionSettings(foundryToml, "profile.default", {
      solc: `"${opts.compilerVersion}"`,
      optimizer: "true",
    });

    const remappings = "@perfect-abstractions/compose/=lib/Compose/src/\n";
    const gitignore = "out/\ncache/\n";

    let readme: string;
    try {
      const templatePath = path.resolve(CLI_ROOT, "src/templates/readme/foundry-readme.md");
      const template = await fs.readFile(templatePath, "utf8");
      readme = template.replace(/\{\{PROJECT_NAME\}\}/g, opts.projectName);
    } catch {
      readme = `# ${opts.projectName}\n\nGenerated by compose init\n`;
    }

    if (updatedFoundryToml !== foundryToml) {
      await fs.writeFile(foundryTomlPath, updatedFoundryToml, "utf8");
    }
    await writeFileIfMissing(path.join(root, "remappings.txt"), remappings);
    await writeFileIfMissing(path.join(root, ".gitignore"), gitignore);
    await fs.writeFile(path.join(root, "README.md"), readme, "utf8");
  },
};

export const foundryAdapter = adapter;
