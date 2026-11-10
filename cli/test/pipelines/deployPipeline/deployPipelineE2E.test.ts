import fs from "node:fs/promises";
import { execFileSync } from "node:child_process";
import os from "node:os";
import path from "node:path";
import { privateKeyToAccount } from "viem/accounts";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  BASE_FACETS,
  ANVIL_PRIVATE_KEY,
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

  async function rpcBlockNumber(): Promise<string> {
    const response = await fetch(harness.rpcUrl, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: [] }),
    });
    const payload = await response.json() as { result?: string };
    if (!response.ok || !payload.result) throw new Error("Unable to read Anvil block number.");
    return payload.result;
  }

  it("generates the managed script and stops before broadcasting", async () => {
    const result = await harness.runDeploy([]);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(0);
    expect(output).toContain("Deploy plan");
    expect(output).toContain("Review this artifact before deploying.");
    expect(output).toContain("When ready, run 'compose deploy --dry-run' to simulate");
    expect(output).toContain("'compose deploy --broadcast' to send transactions");

    const script = await fs.readFile(
      path.join(harness.projectRoot, "script", "ComposeDeploy.s.sol"),
      "utf8",
    );
    expect(script).toMatch(/^\/\* compose-plan-hash: 0x[0-9a-f]{64} \*\/$/m);
    expect(script).toContain("CounterFacet counterFacet = new CounterFacet();");

    await expect(fs.access(path.join(harness.projectRoot, "compose.lock"))).rejects.toThrow();
  }, 120_000);

  it("simulates the reviewed script on a fork without changing the target chain or lock", async () => {
    await harness.runDeploy([]);
    const blockBefore = await rpcBlockNumber();

    const result = await harness.runDeploy([
      "--dry-run",
      "--",
      "--sender",
      privateKeyToAccount(ANVIL_PRIVATE_KEY).address,
    ]);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(0);
    expect(output).toContain("Simulation succeeded");
    expect(output).toContain("No transactions were broadcast");
    expect(output).toMatch(/(Estimated total gas used for script|Total simulated gas)/);
    expect(await rpcBlockNumber()).toBe(blockBefore);
    await expect(fs.access(path.join(harness.projectRoot, "compose.lock"))).rejects.toThrow();
  }, 180_000);

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

  it("uses the command RPC override for Foundry preflight, broadcast, and verification", async () => {
    await harness.writeComposeJson(BASE_FACETS, "http://127.0.0.1:1");

    const generate = await harness.runDeploy([
      "--redeploy",
      "--rpc-url",
      harness.rpcUrl,
    ]);
    const generateOutput = `${generate.stdout}\n${generate.stderr}`;
    expect(generate.code, generateOutput).toBe(0);
    expect(generateOutput).toContain("CLI override");

    const result = await harness.runDeploy([
      "--redeploy",
      "--rpc-url",
      harness.rpcUrl,
      "--broadcast",
      ...SIGNER_ARGS,
    ]);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(0);
    expect(output).toContain("Deployed");
    const deployment = await harness.readDeployment();
    expect(deployment.diamond).toMatch(/^0x[0-9a-fA-F]{40}$/);
  }, 180_000);

  it("deploys with a Compose account alias backed by a Foundry keystore", async () => {
    const home = await fs.mkdtemp(path.join(os.tmpdir(), "compose-account-home-"));
    const password = "compose-e2e-keystore-password";
    const deployerAddress = privateKeyToAccount(ANVIL_PRIVATE_KEY).address;
    const passwordFile = path.join(harness.projectRoot, ".compose-e2e-password");
    const childEnv = { HOME: home, ETH_PASSWORD: passwordFile };

    try {
      await fs.writeFile(passwordFile, `${password}\n`, { encoding: "utf8", mode: 0o600 });
      execFileSync("cast", [
        "wallet",
        "import",
        "compose-e2e-deployer",
        "--private-key",
        ANVIL_PRIVATE_KEY,
        "--unsafe-password",
        password,
      ], { cwd: harness.projectRoot, env: { ...process.env, ...childEnv }, stdio: "pipe" });

      await harness.writeComposeJson(BASE_FACETS, harness.rpcUrl);

      const setup = await harness.runAccount([
        "setup",
        "deployer",
        "--foundry-account",
        "compose-e2e-deployer",
        "--chain",
        "local",
      ], childEnv);
      const setupOutput = `${setup.stdout}\n${setup.stderr}`;
      expect(setup.code, setupOutput).toBe(0);
      expect(setupOutput).toContain(`Registered account 'deployer' at ${deployerAddress}`);
      expect(setupOutput).not.toContain("cast wallet import");
      expect(setupOutput).not.toContain(ANVIL_PRIVATE_KEY);
      expect(setupOutput.split(deployerAddress).length - 1).toBe(1);

      const list = await harness.runAccount(["list"], childEnv);
      const listOutput = `${list.stdout}\n${list.stderr}`;
      expect(list.code, listOutput).toBe(0);
      expect(listOutput).toContain(`deployer: ${deployerAddress}`);
      expect(listOutput).toContain("Default for local: deployer");

      const check = await harness.runAccount(["check", "deployer", "--chain", "local"], childEnv);
      const checkOutput = `${check.stdout}\n${check.stderr}`;
      expect(check.code, checkOutput).toBe(0);
      expect(checkOutput).toContain(`Account 'deployer' is available on local: ${deployerAddress}`);
      expect(checkOutput).not.toContain(ANVIL_PRIVATE_KEY);
      expect(checkOutput.split(deployerAddress).length - 1).toBe(1);

      const generate = await harness.runDeploy(["--account", "deployer", "--redeploy"], childEnv);
      const generateOutput = `${generate.stdout}\n${generate.stderr}`;
      expect(generate.code, generateOutput).toBe(0);

      const result = await harness.runDeploy([
        "--account",
        "deployer",
        "--redeploy",
        "--broadcast",
        "--",
        "--password-file",
        passwordFile,
      ], childEnv);
      const output = `${result.stdout}\n${result.stderr}`;

      expect(result.code, output).toBe(0);
      expect(output).toContain("Signer:   deployer");
      expect(output).toContain("Deployer:");
      const deployment = await harness.readDeployment();
      expect(deployment.deployer?.toLowerCase()).toBe(deployerAddress.toLowerCase());
    } finally {
      await fs.rm(passwordFile, { force: true });
      await fs.rm(home, { recursive: true, force: true });
    }
  }, 180_000);

});
