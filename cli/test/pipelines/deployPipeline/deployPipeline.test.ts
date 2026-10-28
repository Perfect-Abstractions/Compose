import fs from "node:fs/promises";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { ComposeContext } from "../../../src/context/types";

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

  it("rejects network endpoint overrides hidden in Foundry passthrough", async () => {
    harness.ctx.param.passthrough = ["--rpc-url", "https://other.example"];

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(output()).toContain("cannot change the planned deployment target");
    expect(output()).toContain("compose deploy --chain <key> and --rpc-url <url>");
  });
});

describe("DeployPipeline dry-run", () => {
  it("requires a prepared script instead of previewing the script source", async () => {
    harness.ctx.param.dryRun = true;
    harness.ctx.param.passthrough = ["--sender", "0x00000000000000000000000000000000000000a1"];

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(output()).toContain("missing, modified, or stale");
    expect(output()).toContain("Run 'compose deploy'");
    expect(output()).toContain("retry with --dry-run");
    expect(output()).not.toContain("--simulate");
    expect(output()).not.toContain("contract ComposeDeployScript is Script");

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
  it("writes the managed script and gives review instructions without prompting or broadcasting", async () => {
    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(true);
    expect(output()).toContain("script/ComposeDeploy.s.sol");
    expect(output()).toContain("Review this artifact before deploying.");
    expect(output()).toContain("compose deploy --dry-run");
    expect(output()).toContain("compose deploy --broadcast");
    expect(output()).not.toContain("Run the deployment script now?");
    expect(output()).not.toContain(harness.projectRoot);

    const source = await fs.readFile(scriptPath(), "utf8");
    expect(source).toMatch(/^\/\* compose-plan-hash: 0x[0-9a-f]{64} \*\/$/m);
    expect(source).toContain("CounterFacet counterFacet = new CounterFacet();");
    await expect(fs.access(path.join(harness.projectRoot, "compose.lock"))).rejects.toThrow();
  });

  it("reuses a script whose rendered-source hash still matches", async () => {
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
    const hardhatScriptPath = path.join(harness.projectRoot, "ignition", "modules", "ComposeDeploy.ts");
    const source = await fs.readFile(hardhatScriptPath, "utf8");
    expect(source).toMatch(/^\/\/ compose-plan-hash: 0x[0-9a-f]{64}$/m);
    expect(source).toContain('buildModule("ComposeDeploy"');
    expect(source).toContain('m.contract("CounterFacet", [], {');
    expect(source).toContain('m.contract("Diamond", [[diamondInspectFacet, counterFacet]], {');
    await expect(fs.access(scriptPath())).rejects.toThrow();
    expect(output()).toContain("ignition/modules/ComposeDeploy.ts");
    expect(output()).toContain("../../src/CounterFacet.sol");
    expect(output()).not.toContain(harness.projectRoot);
  });
});

describe("DeployPipeline broadcast gating", () => {
  it("refuses --broadcast when the script is missing or stale and stdin is not interactive", async () => {
    harness.ctx.param.broadcast = true;

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(ctx.status.failedAt).toBe("deployScript");
    expect(output()).toContain("missing, modified, or stale");
  });

  it("refuses --broadcast when an existing script belongs to another plan", async () => {
    await fs.mkdir(path.dirname(scriptPath()), { recursive: true });
    await fs.writeFile(scriptPath(), `// compose-plan-hash: 0x${"ef".repeat(32)}\n`, "utf8");
    harness.ctx.param.broadcast = true;

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(output()).toContain("missing, modified, or stale");
  });

  it("refuses --broadcast when the body changed but the plan marker is unchanged", async () => {
    await executePipeline(harness.ctx);
    const originalSource = await fs.readFile(scriptPath(), "utf8");
    const modifiedSource = originalSource.replace(
      "        vm.stopBroadcast();",
      "        payable(address(0xdead)).transfer(1 ether);\n        vm.stopBroadcast();",
    );
    expect(modifiedSource).not.toBe(originalSource);
    const planMarker = originalSource.match(/\/\* compose-plan-hash: 0x[0-9a-f]{64} \*\//)?.[0];
    expect(planMarker).toBeDefined();
    if (!planMarker) throw new Error("Generated script is missing its plan hash marker.");
    expect(modifiedSource).toContain(planMarker);
    await fs.writeFile(scriptPath(), modifiedSource, "utf8");
    harness.ctx.param.broadcast = true;

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(ctx.status.failedAt).toBe("deployScript");
    expect(output()).toContain("missing, modified, or stale");
    await expect(fs.readFile(scriptPath(), "utf8")).resolves.toBe(modifiedSource);
  });

  it("keeps the reviewable Ignition module stable across supported toolbox choices", async () => {
    await harness.writeComposeJson(DEFAULT_FACETS, { framework: "hardhat" });
    await executePipeline(harness.ctx);

    const hardhatModulePath = path.join(harness.projectRoot, "ignition", "modules", "ComposeDeploy.ts");
    const ethersSource = await fs.readFile(hardhatModulePath, "utf8");

    await fs.writeFile(
      path.join(harness.projectRoot, "package.json"),
      JSON.stringify({
        type: "module",
        devDependencies: {
          hardhat: "^3.8.0",
          "@nomicfoundation/hardhat-toolbox-viem": "^5.0.0",
        },
      }),
      "utf8",
    );
    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(true);
    await expect(fs.readFile(hardhatModulePath, "utf8")).resolves.toBe(ethersSource);
  });
});

describe("DeployPipeline artifact freshness", () => {
  it("does not regenerate a missing or stale script before broadcast", async () => {
    harness.ctx.param.broadcast = true;
    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(output()).toContain("Run 'compose deploy', review the generated artifact");
    await expect(fs.access(scriptPath())).rejects.toThrow();
  });

  it("refuses a script modified after review", async () => {
    await executePipeline(harness.ctx);
    const modifiedSource = `${await fs.readFile(scriptPath(), "utf8")}\n// changed\n`;
    await fs.writeFile(scriptPath(), modifiedSource, "utf8");
    harness.ctx.param.broadcast = true;

    const ctx = await executePipeline(harness.ctx);

    expect(ctx.status.success).toBe(false);
    expect(output()).toContain("missing, modified, or stale");
    await expect(fs.readFile(scriptPath(), "utf8")).resolves.toBe(modifiedSource);
  });
});
