import fs from "node:fs/promises";
import path from "node:path";
import type { Hex } from "viem";
import { ComposeContext } from "../../../context/types";
import {
  BroadcastTransaction,
  ConfigOptions,
  DeployCommand,
  DeployCommandOptions,
  FrameworkCommand,
  IFrameworkAdapter,
  SolidityAstSource,
  TestCommandOptions,
} from "../interface";
import { toPosixPath, writeFileIfMissing } from "../../../utils/files";
import { runCommand } from "../../../utils/exec";
import {
  composePackageSubpath,
  isComposePackagePath,
} from "../../../utils/soliditySources";
import { CLI_ROOT } from "../../../utils/cliRoot";
import { isSourceUnitAst, listJsonFiles, uniqueAstSources } from "../../../utils/solidityAst";
import { yellow } from "../../../utils/terminal";
import {
  buildFoundryPackageJson,
  ensureGitignoreEntry,
  ensureTomlSectionSettings,
} from "./helpers";

/** Framework adapter for Foundry-based Diamond projects. */
const MANAGED_SCRIPT_NAME = "ComposeDeploy.s.sol";
const MANAGED_SCRIPT_CONTRACT = "ComposeDeployScript";

/**
 * Installs the generated project's npm dev dependencies (the Compose CLI).
 *
 * Foundry projects build and test without npm, so a failed install only warns:
 * the user can rerun `npm install` later to get the local `npx compose` binary.
 *
 * @param projectRoot - Absolute path of the generated project.
 */
async function installNpmDependencies(projectRoot: string): Promise<void> {
  try {
    await runCommand("npm", ["install"], { cwd: projectRoot });
  } catch {
    console.log(yellow(
      "Could not install npm dependencies. Run `npm install` inside the project "
      + "to use the local Compose CLI with `npx compose`.",
    ));
  }
}

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

    await fs.writeFile(
      path.join(root, "package.json"),
      buildFoundryPackageJson(String(ctx.param.projectName ?? "my-diamond")),
      "utf8",
    );
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

    const gitignorePath = path.join(root, ".gitignore");
    let gitignore = "out/\ncache/\n";
    try {
      gitignore = await fs.readFile(gitignorePath, "utf8");
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
    const updatedGitignore = ensureGitignoreEntry(gitignore, "node_modules/");
    if (updatedGitignore !== gitignore) {
      await fs.writeFile(gitignorePath, updatedGitignore, "utf8");
    }

    await fs.writeFile(path.join(root, "README.md"), readme, "utf8");

    if (opts.installDeps) {
      await installNpmDependencies(root);
    }
  },

  getManagedDeployScriptPath(projectRoot: string): string {
    return path.join(projectRoot, "script", MANAGED_SCRIPT_NAME);
  },

  getManagedDeployResultPath(): string | null {
    // Foundry records deployments in the run broadcast, not a result file.
    return null;
  },

  createDeployCommand(opts: DeployCommandOptions): DeployCommand {
    const relativeScriptPath = toPosixPath(path.relative(opts.projectRoot, opts.scriptPath));
    return {
      command: "forge",
      args: [
        "script",
        `${relativeScriptPath}:${MANAGED_SCRIPT_CONTRACT}`,
        "--rpc-url",
        opts.rpcUrl,
        "--broadcast",
        ...opts.passthrough,
      ],
    };
  },

  createTestCommand(opts: TestCommandOptions): FrameworkCommand {
    return {
      command: "forge",
      args: ["test", ...opts.passthrough],
    };
  },

  async readDeployedBytecode(
    projectRoot: string,
    sourcePath: string,
    contractName: string,
  ): Promise<Hex | undefined> {
    const artifactPath = path.join(
      projectRoot,
      "out",
      path.basename(sourcePath),
      `${contractName}.json`,
    );
    try {
      const artifact = JSON.parse(await fs.readFile(artifactPath, "utf8")) as {
        deployedBytecode?: { object?: unknown };
      };
      const object = artifact.deployedBytecode?.object;
      return typeof object === "string" && object.length > 2 ? (object as Hex) : undefined;
    } catch {
      return undefined;
    }
  },

  async readBroadcastTransactions(
    projectRoot: string,
    scriptPath: string,
    chainId: number,
  ): Promise<BroadcastTransaction[]> {
    const broadcastPath = path.join(
      projectRoot,
      "broadcast",
      path.basename(scriptPath),
      String(chainId),
      "run-latest.json",
    );

    let raw: unknown;
    try {
      raw = JSON.parse(await fs.readFile(broadcastPath, "utf8")) as unknown;
    } catch {
      return [];
    }

    const transactions = (raw as { transactions?: unknown }).transactions;
    if (!Array.isArray(transactions)) return [];

    return (transactions as Array<Record<string, unknown>>).map((transaction) => ({
      contractAddress: typeof transaction.contractAddress === "string" ? transaction.contractAddress : null,
      contractName: typeof transaction.contractName === "string" ? transaction.contractName : null,
      txHash: typeof transaction.hash === "string" ? transaction.hash : null,
    }));
  },
};

export const foundryAdapter = adapter;
