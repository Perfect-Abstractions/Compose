import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { FrameworkModule } from "../../../src/modules/framework/module";

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

describe("FrameworkModule.assertHardhat3", () => {
  it.each(["^3.8.0", "3.21.0"])("accepts a supported Hardhat 3 version (%s)", async (version) => {
    await writePackage({ devDependencies: { hardhat: version } });
    expect(() => FrameworkModule.assertHardhat3(projectRoot)).not.toThrow();
  });

  it.each(["^2.22.0", "^3.0.0"])("rejects an unsupported Hardhat version (%s)", async (version) => {
    await writePackage({ devDependencies: { hardhat: version } });
    expect(() => FrameworkModule.assertHardhat3(projectRoot)).toThrow("Hardhat 3.8 or newer");
  });

  it("requires a declared or installed Hardhat dependency", async () => {
    await writePackage({ devDependencies: {} });
    expect(() => FrameworkModule.assertHardhat3(projectRoot)).toThrow("Could not determine the Hardhat version");
  });
});
