import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  assertHardhat3,
  detectHardhatToolbox,
} from "../../../../src/adapters/IFrameworkAdapter/hardhatAdapter/helpers";

let projectRoot: string;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-hardhat-version-"));
});

afterEach(async () => {
  await fs.rm(projectRoot, { recursive: true, force: true });
});

async function writePackage(packageJson: unknown): Promise<void> {
  await fs.writeFile(path.join(projectRoot, "package.json"), JSON.stringify(packageJson), "utf8");
}

describe("assertHardhat3", () => {
  it.each(["^3.8.0", "3.21.0"])("accepts a supported Hardhat 3 version (%s)", async (version) => {
    await writePackage({ devDependencies: { hardhat: version } });
    expect(() => assertHardhat3(projectRoot)).not.toThrow();
  });

  it.each(["^2.22.0", "^3.0.0"])("rejects an unsupported Hardhat version (%s)", async (version) => {
    await writePackage({ devDependencies: { hardhat: version } });
    expect(() => assertHardhat3(projectRoot)).toThrow("Hardhat 3.8 or newer");
  });

  it("requires a declared or installed Hardhat dependency", async () => {
    await writePackage({ devDependencies: {} });
    expect(() => assertHardhat3(projectRoot)).toThrow("Could not determine the Hardhat version");
  });
});

describe("detectHardhatToolbox", () => {
  it.each([
    ["@nomicfoundation/hardhat-toolbox-viem"],
    ["@nomicfoundation/hardhat-viem"],
  ])("detects the viem toolbox from %s", async (dependency) => {
    await writePackage({ devDependencies: { [dependency]: "^5.0.0" } });
    await expect(detectHardhatToolbox(projectRoot)).resolves.toBe("viem");
  });

  it.each([
    ["@nomicfoundation/hardhat-toolbox-mocha-ethers"],
    ["@nomicfoundation/hardhat-ethers"],
  ])("detects the ethers toolbox from %s", async (dependency) => {
    await writePackage({ dependencies: { [dependency]: "^3.0.0" } });
    await expect(detectHardhatToolbox(projectRoot)).resolves.toBe("ethers");
  });

  it("rejects a project without a supported toolbox", async () => {
    await writePackage({ devDependencies: { hardhat: "^3.8.0" } });
    await expect(detectHardhatToolbox(projectRoot)).rejects.toThrow(
      "Compose requires @nomicfoundation/hardhat-ethers or @nomicfoundation/hardhat-viem",
    );
  });

  it("rejects a missing package.json", async () => {
    await expect(detectHardhatToolbox(projectRoot)).rejects.toThrow(
      "Cannot determine the Hardhat toolbox",
    );
  });

  it("rejects an invalid package.json", async () => {
    await fs.writeFile(path.join(projectRoot, "package.json"), "{not json", "utf8");
    await expect(detectHardhatToolbox(projectRoot)).rejects.toThrow(
      "Cannot determine the Hardhat toolbox",
    );
  });
});
