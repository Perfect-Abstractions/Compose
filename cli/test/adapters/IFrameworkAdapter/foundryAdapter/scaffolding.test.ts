import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CLI_DEV_DEPENDENCY_VERSION, CLI_PACKAGE_NAME } from "../../../../src/utils/metadata";

const { runCommand } = vi.hoisted(() => ({ runCommand: vi.fn(async () => undefined) }));

vi.mock("../../../../src/utils/exec", () => ({ runCommand }));

import { foundryAdapter } from "../../../../src/adapters/IFrameworkAdapter/foundryAdapter/adapter";
import { ConfigOptions } from "../../../../src/adapters/IFrameworkAdapter/interface";
import { Context } from "../../../../src/context/context";
import { ComposeContext } from "../../../../src/context/types";

function createContext(projectRoot: string, installDeps: boolean): ComposeContext {
  const ctx = Context.create();
  ctx.param.projectRoot = projectRoot;
  ctx.param.projectName = "my-diamond";
  ctx.param.installDeps = installDeps;
  return ctx;
}

function configOptions(installDeps: boolean): ConfigOptions {
  return {
    compilerVersion: "0.8.30",
    projectName: "my-diamond",
    installDeps,
  };
}

/** Tests Foundry scaffolding writes with the framework commands mocked. */
describe("foundryAdapter project scaffolding", () => {
  let projectRoot: string;

  beforeEach(async () => {
    projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-foundry-init-"));
    runCommand.mockClear();
  });

  afterEach(async () => {
    await fs.rm(projectRoot, { recursive: true, force: true });
  });

  it("writes a package.json that makes the Compose CLI available locally", async () => {
    await foundryAdapter.initProject(createContext(projectRoot, false));

    const packageJson = JSON.parse(
      await fs.readFile(path.join(projectRoot, "package.json"), "utf8"),
    ) as {
      name: string;
      scripts: Record<string, string>;
      devDependencies: Record<string, string>;
    };

    expect(packageJson.name).toBe("my-diamond");
    expect(packageJson.scripts).toEqual({
      build: "forge build",
      test: "forge test",
      fmt: "forge fmt",
      validate: "compose validate",
      deploy: "compose deploy",
    });
    expect(packageJson.devDependencies).toEqual({
      [CLI_PACKAGE_NAME]: CLI_DEV_DEPENDENCY_VERSION,
    });
    expect(runCommand).toHaveBeenCalledWith("forge", ["init", "."], { cwd: projectRoot });
  });

  it("installs npm dependencies during writeConfig when enabled", async () => {
    await foundryAdapter.writeConfig(createContext(projectRoot, true), configOptions(true));

    expect(runCommand).toHaveBeenCalledWith("npm", ["install"], { cwd: projectRoot });
  });

  it("skips npm install when dependency installation is disabled", async () => {
    await foundryAdapter.writeConfig(createContext(projectRoot, false), configOptions(false));

    expect(runCommand).not.toHaveBeenCalledWith("npm", ["install"], { cwd: projectRoot });
  });

  it("adds Sepolia RPC and compile settings without overwriting existing config", async () => {
    await fs.writeFile(
      path.join(projectRoot, "foundry.toml"),
      [
        "[profile.default]",
        'solc = "0.8.28"',
        "",
        "[rpc_endpoints]",
        'mainnet = "https://ethereum.example"',
        "",
      ].join("\n"),
      "utf8",
    );

    await foundryAdapter.writeConfig(createContext(projectRoot, false), configOptions(false));

    const foundryToml = await fs.readFile(path.join(projectRoot, "foundry.toml"), "utf8");
    expect(foundryToml).toContain('solc = "0.8.28"');
    expect(foundryToml).toContain("optimizer = true");
    expect(foundryToml).toContain("[rpc_endpoints]");
    expect(foundryToml).toContain('sepolia = "${SEPOLIA_RPC_URL}"');
    expect(foundryToml).toContain('mainnet = "https://ethereum.example"');
    await expect(fs.readFile(path.join(projectRoot, ".env.example"), "utf8"))
      .resolves.toContain("SEPOLIA_RPC_URL=");
  });

  it("warns and keeps going when npm install fails", async () => {
    runCommand.mockRejectedValueOnce(new Error("npm unavailable"));
    const logs = vi.spyOn(console, "log").mockImplementation(() => undefined);

    try {
      await expect(
        foundryAdapter.writeConfig(createContext(projectRoot, true), configOptions(true)),
      ).resolves.toBeUndefined();
      expect(logs.mock.calls.flat().join("\n")).toContain("Could not install npm dependencies");
    } finally {
      logs.mockRestore();
    }
  });

  it("adds node_modules to an existing .gitignore without dropping forge entries", async () => {
    await fs.writeFile(path.join(projectRoot, ".gitignore"), "out/\ncache/\n", "utf8");

    await foundryAdapter.writeConfig(createContext(projectRoot, false), configOptions(false));

    await expect(
      fs.readFile(path.join(projectRoot, ".gitignore"), "utf8"),
    ).resolves.toBe("out/\ncache/\nnode_modules/\n");
  });
});
