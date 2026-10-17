import fs from "node:fs/promises";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { ComposeContext } from "../../../src/context/types";

const mocks = vi.hoisted(() => ({
  isInteractive: vi.fn(() => false),
  confirm: vi.fn(async () => false),
}));

vi.mock("../../../src/utils/inquirer", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../../src/utils/inquirer")>();
  return {
    ...actual,
    isInteractive: mocks.isInteractive,
    loadPrompts: async () => ({ confirm: mocks.confirm }),
  };
});

import { DeployPipeline } from "../../../src/pipelines/deployPipeline";
import {
  createDeployProjectHarness,
  DEFAULT_FACET_ADDRESSES,
  DEFAULT_FACETS,
  deploymentRecord,
  type DeployProjectHarness,
} from "../../modules/deployPlan/harness";

let harness: DeployProjectHarness;
let logSpy: ReturnType<typeof vi.spyOn>;
let errorSpy: ReturnType<typeof vi.spyOn>;

beforeEach(async () => {
  harness = await createDeployProjectHarness();
  logSpy = vi.spyOn(console, "log").mockImplementation(() => {});
  errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
  mocks.isInteractive.mockReturnValue(false);
  mocks.confirm.mockReset().mockResolvedValue(false);
});

afterEach(async () => {
  vi.restoreAllMocks();
  await harness.cleanup();
});

function output(): string {
  return [...logSpy.mock.calls, ...errorSpy.mock.calls]
    .map((call) => call.map((value) => String(value)).join(" "))
    .join("\n");
}

function scriptPath(): string {
  return path.join(harness.projectRoot, "script", "ComposeDeploy.s.sol");
}

async function executePipeline(ctx: ComposeContext): Promise<ComposeContext> {
  return DeployPipeline.execute(ctx);
}

describe("DeployPipeline option handling", () => {
  it("rejects --dry-run together with --broadcast", async () => {
    harness.ctx.param.dryRun = true;
    harness.ctx.param.broadcast = true;

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(output()).toContain("Use either --dry-run or --broadcast");
  });
});

describe("DeployPipeline dry-run", () => {
  it("prints the plan and the generated script without writing anything", async () => {
    harness.ctx.param.dryRun = true;

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(true);
    expect(output()).toContain("Deploy plan");
    expect(output()).toContain("Generated script");
    expect(output()).toContain("contract ComposeDeployScript is Script");
    expect(output()).toContain("Dry run: no files were written.");

    await expect(fs.access(scriptPath())).rejects.toThrow();
    await expect(fs.access(path.join(harness.projectRoot, "compose.lock"))).rejects.toThrow();
  });
});

describe("DeployPipeline in-sync", () => {
  it("reports nothing to do when the lock record matches compose.json", async () => {
    await harness.writeLock({
      CounterDiamond: { local: { default: deploymentRecord(DEFAULT_FACET_ADDRESSES) } },
    });

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(true);
    expect(output()).toContain("In sync");
    await expect(fs.access(scriptPath())).rejects.toThrow();
  });
});

describe("DeployPipeline composition drift", () => {
  it("prints the diff and stops without generating a script", async () => {
    await harness.writeLock({
      CounterDiamond: {
        local: {
          default: deploymentRecord({
            DiamondInspectFacet: DEFAULT_FACET_ADDRESSES.DiamondInspectFacet,
          }),
        },
      },
    });

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(ctx.status.stopped).toBe(true);
    expect(ctx.status.failedAt).toBe("deployPlan");
    expect(output()).toContain("differs from compose.json");
    expect(output()).toContain("CounterFacet");
    await expect(fs.access(scriptPath())).rejects.toThrow();
  });
});

describe("DeployPipeline script generation", () => {
  it("writes the managed script and stops before broadcasting when non-interactive", async () => {
    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(true);
    expect(output()).toContain("Script: script/ComposeDeploy.s.sol");
    expect(output()).toContain("compose deploy --broadcast");
    expect(output()).not.toContain(harness.projectRoot);

    const source = await fs.readFile(scriptPath(), "utf8");
    expect(source).toMatch(/^\/\/ compose-plan-hash: 0x[0-9a-f]{64}$/m);
    expect(source).toContain("CounterFacet counterFacet = new CounterFacet();");
    await expect(fs.access(path.join(harness.projectRoot, "compose.lock"))).rejects.toThrow();
  });

  it("reuses a script whose plan hash still matches", async () => {
    await executePipeline(harness.ctx);
    const firstWrite = await fs.stat(scriptPath());
    await new Promise((resolve) => setTimeout(resolve, 20));

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(true);
    const secondWrite = await fs.stat(scriptPath());
    expect(secondWrite.mtimeMs).toBe(firstWrite.mtimeMs);
  });
});

describe("DeployPipeline framework selection", () => {
  it("generates the Hardhat managed script for a Hardhat project", async () => {
    await harness.writeComposeJson(DEFAULT_FACETS, { framework: "hardhat" });

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(true);
    const hardhatScriptPath = path.join(harness.projectRoot, "scripts", "compose-deploy.ts");
    const source = await fs.readFile(hardhatScriptPath, "utf8");
    expect(source).toMatch(/^\/\/ compose-plan-hash: 0x[0-9a-f]{64}$/m);
    expect(source).toContain('import { network } from "hardhat";');
    expect(source).toContain('await network.create({ network: "local" });');
    expect(source).toContain('await ethers.deployContract("CounterFacet");');
    await expect(fs.access(scriptPath())).rejects.toThrow();
    expect(output()).toContain("Script: scripts/compose-deploy.ts");
    expect(output()).not.toContain(harness.projectRoot);
  });
});

describe("DeployPipeline broadcast gating", () => {
  it("refuses --broadcast when the script is missing or stale and stdin is not interactive", async () => {
    harness.ctx.param.broadcast = true;

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(ctx.status.failedAt).toBe("deployScript");
    expect(output()).toContain("missing or stale");
  });

  it("refuses --broadcast when an existing script belongs to another plan", async () => {
    await fs.mkdir(path.dirname(scriptPath()), { recursive: true });
    await fs.writeFile(scriptPath(), `// compose-plan-hash: 0x${"ef".repeat(32)}\n`, "utf8");
    harness.ctx.param.broadcast = true;

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(output()).toContain("missing or stale");
  });
});

describe("DeployPipeline interactive review", () => {
  it("prints the script path before asking to run it and stops when declined", async () => {
    mocks.isInteractive.mockReturnValue(true);

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(true);
    expect(mocks.confirm).toHaveBeenCalledWith({
      message: "Run the deployment script now?",
      default: true,
    });

    const printed = output();
    expect(printed).toContain("Script: script/ComposeDeploy.s.sol");
    expect(printed).not.toContain("contract ComposeDeployScript is Script");
    expect(printed.indexOf("Script: script/ComposeDeploy.s.sol")).toBeLessThan(
      printed.indexOf("Review it, then run"),
    );
  });

  it("prints the path of a regenerated script before broadcasting it", async () => {
    harness.ctx.param.broadcast = true;
    mocks.isInteractive.mockReturnValue(true);
    mocks.confirm.mockResolvedValueOnce(true).mockResolvedValueOnce(false);

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(true);
    expect(mocks.confirm).toHaveBeenNthCalledWith(1, {
      message: "The managed deploy script is missing or stale. Regenerate it?",
      default: true,
    });
    expect(mocks.confirm).toHaveBeenNthCalledWith(2, {
      message: "Run the deployment script now?",
      default: true,
    });
    expect(output()).toContain("Script: script/ComposeDeploy.s.sol");
    expect(output()).not.toContain("contract ComposeDeployScript is Script");
    await expect(fs.access(scriptPath())).resolves.toBeUndefined();
  });
});
