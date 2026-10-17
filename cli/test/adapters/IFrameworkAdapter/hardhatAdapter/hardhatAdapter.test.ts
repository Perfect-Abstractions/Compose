import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { beforeAll, describe, expect, it } from "vitest";
import { hardhatAdapter } from "../../../../src/adapters/IFrameworkAdapter/hardhatAdapter/adapter";
import { resolveHardhatAstSourcePath } from "../../../../src/adapters/IFrameworkAdapter/hardhatAdapter/helpers";
import { Context } from "../../../../src/context/context";
import { ConfigModule } from "../../../../src/modules/config/module";
import { canonicalizeAst } from "../canonicalAst";
import {
  createHardhatAdapterFixtureHarness,
  ensureHardhatFixtureDependencies,
} from "./harness";

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
  it("scaffolds a local network entry for the default Anvil RPC", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-hardhat-config-"));
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;
    ctx.param.base = "none";
    ctx.param.toolbox = "ethers";
    await ConfigModule.loadBasesCatalog(ctx);

    try {
      await hardhatAdapter.writeConfig(ctx, {
        compilerVersion: "0.8.30",
        projectName: "hardhat-config-fixture",
        installDeps: false,
      });

      const config = await fs.readFile(path.join(projectRoot, "hardhat.config.ts"), "utf8");

      expect(config).toContain(`  networks: {
    local: {
      type: "http",
      chainType: "l1",
      url: "http://127.0.0.1:8545",
      accounts: "remote",
    },
  },`);

      const gitignore = await fs.readFile(path.join(projectRoot, ".gitignore"), "utf8");
      expect(gitignore).toContain("cache/");
      expect(gitignore).not.toContain(".cache/");

    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });
});
