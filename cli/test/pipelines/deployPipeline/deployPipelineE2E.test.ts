import fs from "node:fs/promises";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  BASE_FACETS,
  createDeployE2EHarness,
  EXTRA_FACET,
  SIGNER_ARGS,
  type DeployE2EHarness,
} from "./deployE2EHarness";

describe.sequential("deploy pipeline E2E", () => {
  let harness: DeployE2EHarness;

  beforeAll(async () => {
    harness = await createDeployE2EHarness();
  }, 180_000);

  afterAll(async () => {
    await harness?.cleanup();
  });

  it("generates the managed script and stops before broadcasting", async () => {
    const result = await harness.runDeploy([]);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(0);
    expect(output).toContain("Deploy plan");
    expect(output).toContain("Review it, then run 'compose deploy --broadcast'");

    const script = await fs.readFile(
      path.join(harness.projectRoot, "script", "ComposeDeploy.s.sol"),
      "utf8",
    );
    expect(script).toMatch(/^\/\/ compose-plan-hash: 0x[0-9a-f]{64}$/m);
    expect(script).toContain("CounterFacet counterFacet = new CounterFacet();");

    await expect(fs.access(path.join(harness.projectRoot, "compose.lock"))).rejects.toThrow();
  }, 120_000);

  it("broadcasts, verifies on-chain, and records the deployment in compose.lock", async () => {
    const result = await harness.runDeploy(["--broadcast", ...SIGNER_ARGS]);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(0);
    expect(output).toContain("Deployed");
    expect(output).toContain("'CounterDiamond' on local (instance 'default')");
    expect(output).not.toContain("On-chain verification failed");

    const deployment = await harness.readDeployment();
    expect(deployment.diamond).toMatch(/^0x[0-9a-fA-F]{40}$/);
    expect(Object.keys(deployment.facets).sort()).toEqual([
      "CounterFacet",
      "DiamondInspectFacet",
    ]);
    expect(deployment.facetHash).toMatch(/^0x[0-9a-f]{64}$/);
    expect(deployment.txHash).toMatch(/^0x[0-9a-f]{64}$/);
    expect(Date.parse(deployment.lastSync)).not.toBeNaN();

    // Foundry runs are recorded from the run broadcast: the capture file is
    // Hardhat-only, so no capture file or capture directory is created.
    await expect(fs.access(path.join(harness.projectRoot, "compose"))).rejects.toThrow();
    await expect(
      fs.access(path.join(harness.projectRoot, "cache", "compose")),
    ).rejects.toThrow();
  }, 180_000);

  it("reports in-sync when compose.json is unchanged", async () => {
    const result = await harness.runDeploy([]);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(0);
    expect(output).toContain("In sync");
  }, 120_000);

  it("stops with the composition diff when compose.json gains a facet", async () => {
    await harness.writeComposeJson({ ...BASE_FACETS, ExtraFacet: EXTRA_FACET });

    const result = await harness.runDeploy([]);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(1);
    expect(output).toContain("differs from compose.json");
    expect(output).toContain("ExtraFacet");
  }, 120_000);

  it("replaces the deployment with --redeploy", async () => {
    const before = await harness.readDeployment();

    const regenerate = await harness.runDeploy(["--redeploy"]);
    const regenerateOutput = `${regenerate.stdout}\n${regenerate.stderr}`;
    expect(regenerate.code, regenerateOutput).toBe(0);

    const result = await harness.runDeploy(["--redeploy", "--broadcast", ...SIGNER_ARGS]);
    const output = `${result.stdout}\n${result.stderr}`;
    expect(result.code, output).toBe(0);
    expect(output).toContain("abandoned and replaced");

    const after = await harness.readDeployment();
    expect(after.diamond).not.toBe(before.diamond);
    expect(Object.keys(after.facets).sort()).toEqual([
      "CounterFacet",
      "DiamondInspectFacet",
      "ExtraFacet",
    ]);
  }, 240_000);

  it("validates the deployed project against the lock", async () => {
    const result = await harness.runValidate();
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(0);
    expect(output).toContain("Validation passed.");
  }, 180_000);
});
