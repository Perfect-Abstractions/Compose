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
import { CLI_DEV_DEPENDENCY_VERSION, CLI_PACKAGE_NAME } from "../../../utils/metadata";
import {
  composePackageSubpath,
  isComposePackagePath,
} from "../../../utils/soliditySources";
import { ScaffoldingModule } from "../../../modules/scaffolding/module";
import { CLI_ROOT } from "../../../utils/cliRoot";
import { isSourceUnitAst, listJsonFiles, uniqueAstSources } from "../../../utils/solidityAst";
import { getHardhatInitTemplate, HARDHAT_INIT_VERSION } from "../../../modules/init/frameworkDeps";
import { withComposeProjectScripts } from "../../../modules/init/projectScripts";
import { FrameworkModule } from "../../../modules/framework/module";
import { resolveHardhatArtifactSourceName, resolveHardhatAstSourcePath } from "./helpers";

/** Framework adapter for Hardhat-based Diamond projects. */
const MANAGED_SCRIPT_NAME = "compose-deploy.ts";
const MANAGED_RUNNER_RELATIVE_PATH = path.join("scripts", ".compose", "ignition-runner.ts");

/** Managed deploy result, kept inside Hardhat's default `cache` directory. */
const MANAGED_RESULT_RELATIVE_PATH = path.join("cache", "compose", "deploy-result.json");

const HARDHAT_TEMPLATE_SAMPLE_FILES = [
  path.join("contracts", "Counter.sol"),
  path.join("contracts", "Counter.t.sol"),
  path.join("test", "Counter.ts"),
  path.join("ignition", "modules", "Counter.ts"),
  path.join("scripts", "send-op-tx.ts"),
];

function updatePackageManifest(
  packageJson: Record<string, unknown>,
  projectName: string,
): Record<string, unknown> {
  const currentDependencies = typeof packageJson.dependencies === "object" && packageJson.dependencies !== null
    ? packageJson.dependencies as Record<string, string>
    : {};
  const currentDevDependencies = typeof packageJson.devDependencies === "object" && packageJson.devDependencies !== null
    ? packageJson.devDependencies as Record<string, string>
    : {};
  const currentScripts = typeof packageJson.scripts === "object" && packageJson.scripts !== null
    ? packageJson.scripts as Record<string, string>
    : {};
  const safeName = projectName.toLowerCase().replace(/[^a-z0-9._-]+/g, "-");

  return {
    ...packageJson,
    name: safeName,
    type: "module",
    engines: {
      ...((typeof packageJson.engines === "object" && packageJson.engines !== null)
        ? packageJson.engines as Record<string, string>
        : {}),
      node: ">=22.13.0",
    },
    dependencies: {
      ...currentDependencies,
      "@perfect-abstractions/compose": "latest",
    },
    devDependencies: {
      ...currentDevDependencies,
      [CLI_PACKAGE_NAME]: CLI_DEV_DEPENDENCY_VERSION,
    },
    scripts: withComposeProjectScripts({
      ...currentScripts,
      build: currentScripts.build ?? "hardhat build",
      test: currentScripts.test ?? "hardhat test",
    }),
  };
}

function appendGitignoreEntries(source: string, entries: string[]): string {
  let updated = source;
  for (const entry of entries) {
    const present = updated.split(/\r?\n/).some((line) => line.trim() === entry);
    if (!present) updated = `${updated.trimEnd()}\n${entry}\n`;
  }
  return updated.endsWith("\n") ? updated : `${updated}\n`;
}

/** Command used to invoke Hardhat's non-interactive official project template. */
export function createHardhatInitCommand(toolbox: string): FrameworkCommand {
  return {
    command: "npx",
    args: [
      "--yes",
      `--package=hardhat@${HARDHAT_INIT_VERSION}`,
      "hardhat",
      "--init",
      "--template",
      getHardhatInitTemplate(toolbox),
    ],
  };
}

/** Removes only the known demo files shipped by Hardhat's selected starter templates. */
export async function removeHardhatTemplateSamples(projectRoot: string): Promise<void> {
  await Promise.all(HARDHAT_TEMPLATE_SAMPLE_FILES.map((relativePath) =>
    fs.rm(path.join(projectRoot, relativePath), { force: true }),
  ));
}

const adapter: IFrameworkAdapter = {
  getContractSourceRoot(projectRoot: string): string {
    return path.join(projectRoot, "contracts");
  },

  getScriptRoot(projectRoot: string): string {
    return path.join(projectRoot, "scripts");
  },

  getTestRoot(projectRoot: string): string {
    return path.join(projectRoot, "test");
  },

  getArtifactDir(projectRoot: string): string {
    return path.join(projectRoot, "artifacts");
  },

  async compile(projectRoot: string): Promise<void> {
    FrameworkModule.assertHardhat3(projectRoot);
    await runCommand("npx", ["hardhat", "build", "--build-profile", "production"], { cwd: projectRoot });
  },

  async resolveSoliditySourcePath(ctx: ComposeContext, sourcePath: string): Promise<string> {
    if (path.isAbsolute(sourcePath)) return sourcePath;

    const root = String(ctx.param.projectRoot ?? "");
    if (isComposePackagePath(sourcePath)) {
      return path.join(
        root,
        "node_modules",
        "@perfect-abstractions",
        "compose",
        composePackageSubpath(sourcePath),
      );
    }

    return path.resolve(root, sourcePath);
  },

  async compileAst(ctx: ComposeContext, sourcePaths: string[]): Promise<SolidityAstSource[]> {
    const root = String(ctx.param.projectRoot ?? "");
    FrameworkModule.assertHardhat3(root);
    await Promise.all(sourcePaths.map((sourcePath) => fs.access(sourcePath)));
    await runCommand("npx", ["hardhat", "compile", "--force"], { cwd: root });

    const sources: SolidityAstSource[] = [];
    const buildInfoPaths = await listJsonFiles(path.join(root, "artifacts", "build-info"));

    for (const buildInfoPath of buildInfoPaths) {
      const buildInfo = JSON.parse(await fs.readFile(buildInfoPath, "utf8")) as {
        output?: { sources?: Record<string, { ast?: unknown }> };
        sources?: Record<string, { ast?: unknown }>;
      };
      const compilerSources = buildInfo.output?.sources ?? buildInfo.sources ?? {};

      for (const [sourceName, compilerSource] of Object.entries(compilerSources)) {
        if (isSourceUnitAst(compilerSource.ast)) {
          sources.push({
            sourceName: resolveHardhatAstSourcePath(root, sourceName),
            ast: compilerSource.ast,
          });
        }
      }
    }

    const uniqueSources = uniqueAstSources(sources);
    if (uniqueSources.length === 0) {
      throw new Error("Hardhat compilation did not produce any Solidity AST source units.");
    }

    return uniqueSources;
  },

  async initProject(ctx: ComposeContext): Promise<void> {
    const root = String(ctx.param.projectRoot ?? "");
    const toolbox = String(ctx.param.toolbox ?? "ethers");
    const command = createHardhatInitCommand(toolbox);
    await runCommand(command.command, command.args, { cwd: root });

    // Compose replaces these sample contracts and tests with its selected
    // facets and generated diamond test, while keeping the official template's
    // project config, plugins, and directory structure.
    await removeHardhatTemplateSamples(root);
  },

  async writeConfig(ctx: ComposeContext, opts: ConfigOptions): Promise<void> {
    const root = String(ctx.param.projectRoot ?? "");
    const selectedFacets = ScaffoldingModule.getSelectedFacets(ctx);
    const packageFacetPaths = selectedFacets
      .map((facet) => facet.entry.path)
      .filter(isComposePackagePath);

    const packageJsonPath = path.join(root, "package.json");
    const packageJson = JSON.parse(await fs.readFile(packageJsonPath, "utf8")) as Record<string, unknown>;
    await fs.writeFile(
      packageJsonPath,
      `${JSON.stringify(updatePackageManifest(packageJson, opts.projectName), null, 2)}\n`,
      "utf8",
    );

    // Keep Hardhat's official config in the single config file, then append a
    // Compose overlay so its plugins and network settings remain intact.
    const officialConfigPath = path.join(root, "hardhat.config.ts");
    const officialConfig = await fs.readFile(officialConfigPath, "utf8");
    const defaultConfigExport = /export\s+default\s+defineConfig\s*\(\s*\{/g;
    const defaultConfigExports = officialConfig.match(defaultConfigExport) ?? [];
    if (defaultConfigExports.length !== 1) {
      throw new Error("Hardhat's official config template did not contain the expected default defineConfig export.");
    }
    const baseConfigSource = officialConfig.replace(
      defaultConfigExport,
      "const baseConfig = defineConfig({",
    );
    const composeConfig = `${baseConfigSource.trimEnd()}

const baseSolidity = typeof baseConfig.solidity === "object" && baseConfig.solidity !== null
  ? baseConfig.solidity
  : {};
const baseProfiles = baseSolidity.profiles ?? {};
const defaultProfile = baseProfiles.default ?? {};
const productionProfile = baseProfiles.production ?? {};
const composeNpmFilesToBuild = ${JSON.stringify(packageFacetPaths)};

export default defineConfig({
  ...baseConfig,
  solidity: {
    ...baseSolidity,
    npmFilesToBuild: [...new Set([...(baseSolidity.npmFilesToBuild ?? []), ...composeNpmFilesToBuild])],
    profiles: {
      ...baseProfiles,
      default: {
        ...defaultProfile,
        version: ${JSON.stringify(opts.compilerVersion)},
        settings: {
          ...defaultProfile.settings,
          optimizer: { ...defaultProfile.settings?.optimizer, enabled: true },
        },
      },
      production: {
        ...productionProfile,
        version: ${JSON.stringify(opts.compilerVersion)},
        settings: {
          ...productionProfile.settings,
          optimizer: { ...productionProfile.settings?.optimizer, enabled: true, runs: 200 },
        },
      },
    },
  },
  networks: {
    ...baseConfig.networks,
    local: {
      type: "http",
      chainType: "l1",
      url: "http://127.0.0.1:8545",
      accounts: "remote",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
  },
});
`;
    await fs.writeFile(officialConfigPath, composeConfig, "utf8");

    const gitignorePath = path.join(root, ".gitignore");
    let gitignore = "";
    try {
      gitignore = await fs.readFile(gitignorePath, "utf8");
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
    await fs.writeFile(
      gitignorePath,
      appendGitignoreEntries(gitignore, [
        "node_modules/",
        "cache/",
        "artifacts/",
        "dist/",
        ".env",
        "scripts/.compose/",
      ]),
      "utf8",
    );

    let readme: string;
    try {
      const templatePath = path.resolve(CLI_ROOT, "src/templates/readme/hardhat-readme.md");
      const template = await fs.readFile(templatePath, "utf8");
      readme = template.replace(/\{\{PROJECT_NAME\}\}/g, opts.projectName);
    } catch {
      readme = `# ${opts.projectName}\n\nGenerated by compose init\n`;
    }
    await fs.writeFile(path.join(root, "README.md"), readme, "utf8");
    await writeFileIfMissing(
      path.join(root, ".env.example"),
      [
        "# Sepolia RPC endpoint used by `compose deploy --chain sepolia`.",
        "SEPOLIA_RPC_URL=",
        "# Deployment signer. Prefer `npx hardhat keystore set SEPOLIA_PRIVATE_KEY`.",
        "SEPOLIA_PRIVATE_KEY=",
        "",
      ].join("\n"),
    );

    await fs.mkdir(path.join(root, "test"), { recursive: true });
    await fs.mkdir(path.join(root, "scripts"), { recursive: true });

    if (opts.installDeps) {
      await runCommand("npm", ["install"], { cwd: root });
    }
  },

  getManagedDeployScriptPath(projectRoot: string): string {
    return path.join(projectRoot, "scripts", MANAGED_SCRIPT_NAME);
  },

  getManagedDeployResultPath(projectRoot: string): string | null {
    return path.join(projectRoot, MANAGED_RESULT_RELATIVE_PATH);
  },

  createDeployCommand(opts: DeployCommandOptions): DeployCommand {
    const relativeScriptPath = toPosixPath(path.relative(opts.projectRoot, opts.scriptPath));
    return {
      command: "npx",
      args: [
        "hardhat",
        "run",
        relativeScriptPath,
        "--network",
        opts.chainKey,
        ...opts.passthrough,
      ],
    };
  },

  createTestCommand(opts: TestCommandOptions): FrameworkCommand {
    return {
      command: "npx",
      args: ["hardhat", "test", ...opts.passthrough],
    };
  },

  async readDeployedBytecode(
    projectRoot: string,
    sourcePath: string,
    contractName: string,
  ): Promise<Hex | undefined> {
    const sourceName = await resolveHardhatArtifactSourceName(projectRoot, sourcePath);
    if (!sourceName) return undefined;

    const artifactPath = path.join(
      projectRoot,
      "artifacts",
      ...sourceName.split("/"),
      `${contractName}.json`,
    );
    try {
      const artifact = JSON.parse(await fs.readFile(artifactPath, "utf8")) as {
        deployedBytecode?: unknown;
      };
      return typeof artifact.deployedBytecode === "string" && artifact.deployedBytecode.length > 2
        ? (artifact.deployedBytecode as Hex)
        : undefined;
    } catch {
      return undefined;
    }
  },

  async readBroadcastTransactions(): Promise<BroadcastTransaction[]> {
    // Hardhat deploy scripts report their transactions in the result file.
    return [];
  },
};

export const hardhatAdapter = adapter;
