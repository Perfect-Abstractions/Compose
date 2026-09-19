import fs from "node:fs/promises";
import path from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { HashingAdapter } from "../../../src/adapters/IHashingAdapter/adapter";
import { InitModule } from "../../../src/modules/init/module";
import { PreflightModule } from "../../../src/modules/preflight/module";
import { ValidationModule } from "../../../src/modules/validation/module";
import { InitPipeline } from "../../../src/pipelines/initPipeline";
import { DependencyResolver } from "../../../src/resolver/dependencyResolver";
import { createInitPipelineHarness, InitPipelineHarness } from "./harness";

type ComposeJson = {
  project: string;
  framework: string;
  diamonds: Record<string, {
    contract: string;
    facets: Record<string, {
      source: string;
      contract: string;
      package?: string;
    }>;
  }>;
};

async function expectFiles(projectRoot: string, files: string[]): Promise<void> {
  await Promise.all(files.map((file) =>
    expect(fs.access(path.join(projectRoot, file))).resolves.toBeUndefined()
  ));
}

async function readComposeJson(projectRoot: string): Promise<ComposeJson> {
  return JSON.parse(
    await fs.readFile(path.join(projectRoot, "compose.json"), "utf8"),
  ) as ComposeJson;
}

function useHarnessDependencies(harness: InitPipelineHarness): void {
  vi.spyOn(InitModule, "showComposeHeader").mockImplementation(() => undefined);
  vi.spyOn(InitModule, "showSuccess").mockImplementation(() => undefined);
  vi.spyOn(PreflightModule, "check").mockImplementation(async (ctx) => ctx);
  vi.spyOn(ValidationModule, "showReport").mockImplementation(async (ctx) => ctx);
  vi.spyOn(DependencyResolver, "resolve").mockResolvedValue({
    [String(harness.ctx.param.framework)]: harness.adapter,
    hashing: HashingAdapter,
  });
}

afterEach(() => {
  vi.restoreAllMocks();
});

/**
 * Exercises the complete InitPipeline with real modules and filesystem output.
 *
 * Framework process and compiler behavior stay behind an IFrameworkAdapter
 * fixture; their real implementations are covered by the adapter test suite.
 */
describe("InitPipeline", () => {
  it.each([
    {
      framework: "foundry" as const,
      projectName: "bare-foundry",
      contract: "src/Diamond.sol:Diamond",
      files: [
        "compose.json",
        "foundry.toml",
        "src/Diamond.sol",
        "script/Deploy.s.sol",
        "test/Diamond.t.sol",
      ],
    },
    {
      framework: "hardhat" as const,
      projectName: "bare-hardhat",
      contract: "contracts/Diamond.sol:Diamond",
      files: [
        "compose.json",
        "package.json",
        "hardhat.config.ts",
        "contracts/Diamond.sol",
        "scripts/deploy.ts",
        "test/Diamond.ts",
      ],
    },
  ])("scaffolds a bare $framework diamond", async ({
    framework,
    projectName,
    contract,
    files,
  }) => {
    const harness = await createInitPipelineHarness(framework, "none", projectName);
    useHarnessDependencies(harness);

    try {
      const result = await InitPipeline.execute(harness.ctx);
      const composeJson = await readComposeJson(harness.projectRoot);
      const diamond = composeJson.diamonds[projectName];

      expect(result.status.success).toBe(true);
      expect(result.state.initValidation?.success).toBe(true);
      expect(result.state.initPipeline?.success).toBe(true);
      expect(composeJson.project).toBe(projectName);
      expect(composeJson.framework).toBe(framework);
      expect(diamond.contract).toBe(contract);
      expect(Object.keys(diamond.facets)).toEqual(["DiamondInspectFacet"]);
      await expectFiles(harness.projectRoot, files);
      expect(harness.adapter.compileAst).toHaveBeenCalledOnce();
    } finally {
      await harness.cleanup();
    }
  });

  it("scaffolds an ERC-20 diamond from non-interactive flags", async () => {
    const harness = await createInitPipelineHarness("foundry", "erc-20", "erc20-foundry");
    useHarnessDependencies(harness);

    try {
      const result = await InitPipeline.execute(harness.ctx);
      const composeJson = await readComposeJson(harness.projectRoot);
      const facetNames = Object.keys(composeJson.diamonds["erc20-foundry"].facets).sort();

      expect(result.status.success).toBe(true);
      expect(result.state.initValidation?.success).toBe(true);
      expect(facetNames).toEqual([
        "DiamondInspectFacet",
        "ERC20ApproveFacet",
        "ERC20DataFacet",
        "ERC20TransferFacet",
      ]);
      expect(harness.adapter.compileAst).toHaveBeenCalledOnce();
    } finally {
      await harness.cleanup();
    }
  });
});
