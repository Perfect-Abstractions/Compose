import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import { createServer, type Server } from "node:http";
import type { AddressInfo } from "node:net";
import os from "node:os";
import path from "node:path";
import { beforeAll, describe, expect, it } from "vitest";
import {
  createHardhatInitCommand,
  hardhatAdapter,
  removeHardhatTemplateSamples,
} from "../../../../src/adapters/IFrameworkAdapter/hardhatAdapter/adapter";
import { resolveHardhatAstSourcePath } from "../../../../src/adapters/IFrameworkAdapter/hardhatAdapter/helpers";
import { Context } from "../../../../src/context/context";
import { ConfigModule } from "../../../../src/modules/config/module";
import { CLI_DEV_DEPENDENCY_VERSION, CLI_PACKAGE_NAME } from "../../../../src/utils/metadata";
import { canonicalizeAst } from "../canonicalAst";
import {
  createHardhatAdapterFixtureHarness,
  ensureHardhatFixtureDependencies,
} from "./harness";

type RPCRequest = { id: number | string | null; method: string };

async function startRPCServer(chainId: number): Promise<{
  url: string;
  methods: string[];
  close(): Promise<void>;
}> {
  const methods: string[] = [];
  const server: Server = createServer((request, response) => {
    const chunks: Buffer[] = [];
    request.on("data", (chunk: Buffer) => chunks.push(chunk));
    request.on("end", () => {
      const payload = JSON.parse(Buffer.concat(chunks).toString("utf8")) as RPCRequest;
      methods.push(payload.method);
      const result = payload.method === "eth_chainId"
        ? `0x${chainId.toString(16)}`
        : payload.method === "net_version"
          ? String(chainId)
          : payload.method === "eth_accounts"
            ? []
            : null;
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify({ jsonrpc: "2.0", id: payload.id, result }));
    });
  });

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address() as AddressInfo;
  return {
    url: `http://127.0.0.1:${address.port}`,
    methods,
    close: () => new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    }),
  };
}

function runHardhatScript(
  projectRoot: string,
  scriptPath: string,
  rpcUrl: string,
): Promise<{ code: number; stdout: string; stderr: string }> {
  const hardhatCliPath = path.join(projectRoot, "node_modules", "hardhat", "dist", "src", "cli.js");
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [hardhatCliPath, "run", scriptPath, "--network", "local"], {
      cwd: projectRoot,
      env: { ...process.env, COMPOSE_DEPLOY_RPC_URL: rpcUrl },
      windowsHide: true,
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk: Buffer) => { stdout += chunk.toString(); });
    child.stderr.on("data", (chunk: Buffer) => { stderr += chunk.toString(); });
    child.once("error", reject);
    child.once("close", (code) => resolve({ code: code ?? 1, stdout, stderr }));
  });
}

/** Tests Hardhat AST compilation, build-info normalization, and config scaffolding. */
describe("hardhatAdapter.compileAst", () => {
  beforeAll(() => ensureHardhatFixtureDependencies(), 120_000);

  it("resolves project and versioned npm source names to readable paths", () => {
    const projectRoot = path.resolve("project-root");

    expect(resolveHardhatAstSourcePath(
      projectRoot,
      "project/contracts/CounterFacet.sol",
    )).toBe(path.join(projectRoot, "contracts", "CounterFacet.sol"));
    expect(resolveHardhatAstSourcePath(
      projectRoot,
      "npm/@perfect-abstractions/compose@0.0.4/diamond/DiamondInspectFacet.sol",
    )).toBe(path.join(
      projectRoot,
      "node_modules",
      "@perfect-abstractions",
      "compose",
      "diamond",
      "DiamondInspectFacet.sol",
    ));
  });

  it(
    "generates and returns a fresh Solidity AST",
    async () => {
      const harness = await createHardhatAdapterFixtureHarness();

      try {
        const buildInfoRoot = path.join(harness.projectRoot, "artifacts", "build-info");
        await expect(fs.access(buildInfoRoot)).rejects.toThrow();

        const result = await hardhatAdapter.compileAst(harness.ctx, [
          path.join(harness.projectRoot, "contracts", "Normal.sol"),
        ]);
        const buildInfoFiles = await fs.readdir(buildInfoRoot);
        const normalSource = result.find(
          (source) => source.sourceName === path.join(
            harness.projectRoot,
            "contracts",
            "Normal.sol",
          ),
        );
        const expected = JSON.parse(
          await fs.readFile(
            path.join(__dirname, "..", "fixtures", "normal", "expected", "hardhat.ast.json"),
            "utf8",
          ),
        );

        expect(buildInfoFiles.some((file) => file.endsWith(".json"))).toBe(true);
        expect(normalSource?.ast.nodeType).toBe("SourceUnit");
        expect(normalSource?.ast.nodes).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              name: "Normal",
              nodeType: "ContractDefinition",
            }),
          ]),
        );
        expect(canonicalizeAst(normalSource!.ast)).toEqual(expected);
      } finally {
        await harness.cleanup();
      }
    },
    30_000,
  );
});

/** Tests Hardhat project config scaffolding written by compose init. */
describe("hardhatAdapter.writeConfig", () => {
  it("adds Compose settings to the official config without creating another config file", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-hardhat-config-"));
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;
    ctx.param.base = "none";
    ctx.param.toolbox = "ethers";
    await ConfigModule.loadBasesCatalog(ctx);

    try {
      await fs.writeFile(path.join(projectRoot, "package.json"), JSON.stringify({
        name: "hardhat-config-fixture",
        private: true,
        type: "module",
        scripts: {
          custom: "echo custom",
          validate: "custom validate",
        },
        devDependencies: {
          hardhat: "^3.8.0",
          "@nomicfoundation/hardhat-toolbox-mocha-ethers": "^3.0.7",
        },
      }), "utf8");
      await fs.writeFile(
        path.join(projectRoot, "hardhat.config.ts"),
        [
          'import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";',
          'import { configVariable, defineConfig } from "hardhat/config";',
          "",
          "export default defineConfig({",
          "  plugins: [hardhatToolboxMochaEthersPlugin],",
          '  solidity: { profiles: { default: { version: "0.8.28" }, production: { version: "0.8.28" } } },',
          '  networks: { sepolia: { type: "http", chainType: "l1", url: configVariable("SEPOLIA_RPC_URL"), accounts: [] } },',
          "});",
          "",
        ].join("\n"),
        "utf8",
      );
      await fs.writeFile(path.join(projectRoot, "tsconfig.json"), JSON.stringify({
        compilerOptions: { module: "node20", target: "es2023", types: ["node", "mocha"] },
      }), "utf8");
      await fs.writeFile(path.join(projectRoot, ".gitignore"), "node_modules/\n", "utf8");

      await hardhatAdapter.writeConfig(ctx, {
        compilerVersion: "0.8.30",
        projectName: "hardhat-config-fixture",
        installDeps: false,
      });

      const config = await fs.readFile(path.join(projectRoot, "hardhat.config.ts"), "utf8");
      expect(config).toContain("const baseConfig = defineConfig({");
      expect(config).toContain("hardhatToolboxMochaEthersPlugin");
      expect(config).toContain('configVariable("SEPOLIA_RPC_URL")');
      expect(config).toContain('configVariable("SEPOLIA_PRIVATE_KEY")');
      expect(config).toContain('url: "http://127.0.0.1:8545"');
      expect(config).toContain('accounts: "remote"');
      expect(config).toContain("npmFilesToBuild:");

      const packageJson = JSON.parse(await fs.readFile(path.join(projectRoot, "package.json"), "utf8"));
      expect(packageJson.devDependencies[CLI_PACKAGE_NAME]).toBe(CLI_DEV_DEPENDENCY_VERSION);
      expect(packageJson.dependencies["@perfect-abstractions/compose"]).toBe("latest");
      expect(packageJson.devDependencies["@nomicfoundation/hardhat-toolbox-mocha-ethers"]).toBe("^3.0.7");
      expect(packageJson.engines.node).toBe(">=22.13.0");
      expect(packageJson.scripts).toEqual({
        custom: "echo custom",
        validate: "custom validate",
        build: "hardhat build",
        test: "hardhat test",
        deploy: "compose deploy",
      });
      expect(JSON.parse(await fs.readFile(path.join(projectRoot, "tsconfig.json"), "utf8")))
        .toMatchObject({ compilerOptions: { module: "node20" } });

      const gitignore = await fs.readFile(path.join(projectRoot, ".gitignore"), "utf8");
      expect(gitignore).toContain("node_modules/");
      expect(gitignore).toContain("cache/");
      expect(gitignore).toContain("scripts/.compose/");
      expect(gitignore).not.toContain(".cache/");

      const envExample = await fs.readFile(path.join(projectRoot, ".env.example"), "utf8");
      expect(envExample).toContain("SEPOLIA_RPC_URL=");
      expect(envExample).toContain("SEPOLIA_PRIVATE_KEY=");

      await expect(
        fs.access(path.join(projectRoot, "scripts")),
      ).resolves.toBeUndefined();
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });
});

/** Verifies Compose invokes Hardhat's official non-interactive template IDs. */
describe("Hardhat official initializer", () => {
  it.each([
    ["ethers", "mocha-ethers"],
    ["viem", "node-test-runner-viem"],
  ])("uses the %s template without setup prompts", (toolbox, template) => {
    expect(createHardhatInitCommand(toolbox)).toEqual({
      command: "npx",
      args: [
        "--yes",
        "--package=hardhat@3.8.0",
        "hardhat",
        "--init",
        "--template",
        template,
      ],
    });
  });

  it("removes only known Hardhat demo files before adding Compose contracts", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-hardhat-template-cleanup-"));
    const sampleFiles = [
      "contracts/Counter.sol",
      "contracts/Counter.t.sol",
      "test/Counter.ts",
      "ignition/modules/Counter.ts",
      "scripts/send-op-tx.ts",
    ];

    try {
      await Promise.all(sampleFiles.map(async (relativePath) => {
        const filePath = path.join(projectRoot, relativePath);
        await fs.mkdir(path.dirname(filePath), { recursive: true });
        await fs.writeFile(filePath, "// official Hardhat sample\n", "utf8");
      }));
      const userFile = path.join(projectRoot, "contracts", "UserFacet.sol");
      await fs.writeFile(userFile, "contract UserFacet {}\n", "utf8");

      await removeHardhatTemplateSamples(projectRoot);

      await Promise.all(sampleFiles.map((relativePath) =>
        expect(fs.access(path.join(projectRoot, relativePath))).rejects.toThrow(),
      ));
      await expect(fs.readFile(userFile, "utf8")).resolves.toBe("contract UserFacet {}\n");
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });
});

describe("Hardhat managed-deploy RPC override", () => {
  beforeAll(() => ensureHardhatFixtureDependencies(), 120_000);

  it("uses the Compose endpoint instead of the configured endpoint", async () => {
    const harness = await createHardhatAdapterFixtureHarness();
    const configuredRPC = await startRPCServer(31337);
    const composeRPC = await startRPCServer(31337);

    try {
      await fs.writeFile(
        path.join(harness.projectRoot, "hardhat.config.ts"),
        `import { defineConfig } from "hardhat/config";\n\nexport default defineConfig({\n  solidity: { version: "0.8.30" },\n  networks: {\n    local: {\n      type: "http",\n      chainType: "l1",\n      url: "${configuredRPC.url}",\n      accounts: "remote",\n    },\n  },\n});\n`,
        "utf8",
      );
      await fs.mkdir(path.join(harness.projectRoot, "scripts"), { recursive: true });
      await fs.writeFile(
        path.join(harness.projectRoot, "scripts", "check-compose-rpc.ts"),
        [
          'import { network } from "hardhat";',
          "const rpcUrl = process.env.COMPOSE_DEPLOY_RPC_URL;",
          'if (!rpcUrl) throw new Error("Missing Compose RPC URL");',
          'const connection = await network.create({ network: "local", override: { url: rpcUrl } });',
          'const chainId = Number(BigInt(String(await connection.provider.request({ method: "eth_chainId", params: [] }))));',
          'console.log("COMPOSE_RPC_RESULT", JSON.stringify({ chainId }));',
          "await connection.close();",
        ].join("\n"),
        "utf8",
      );

      const result = await runHardhatScript(
        harness.projectRoot,
        "scripts/check-compose-rpc.ts",
        composeRPC.url,
      );
      const output = `${result.stdout}\n${result.stderr}`;
      expect(result.code, output).toBe(0);
      expect(output).toContain('COMPOSE_RPC_RESULT {"chainId":31337}');
      expect(composeRPC.methods).toContain("eth_chainId");
      expect(configuredRPC.methods).toEqual([]);
    } finally {
      await harness.cleanup();
      await Promise.all([configuredRPC.close(), composeRPC.close()]);
    }
  }, 60_000);
});
