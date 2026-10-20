import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { runCommand } = vi.hoisted(() => ({ runCommand: vi.fn(async () => undefined) }));

vi.mock("../../src/utils/exec", () => ({ runCommand }));

import { Context } from "../../src/context/context";
import { TestPipeline } from "../../src/pipelines/testPipeline";

let projectRoot: string;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-test-pipeline-"));
  runCommand.mockClear();
});

afterEach(async () => {
  await fs.rm(projectRoot, { recursive: true, force: true });
});

describe("TestPipeline", () => {
  it("runs forge test for a Foundry project", async () => {
    await fs.writeFile(path.join(projectRoot, "foundry.toml"), "", "utf8");
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;

    await TestPipeline.execute(ctx);

    expect(runCommand).toHaveBeenCalledWith("forge", ["test"], { cwd: projectRoot });
  });

  it("runs hardhat test for a Hardhat project", async () => {
    await fs.writeFile(path.join(projectRoot, "hardhat.config.ts"), "", "utf8");
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;

    await TestPipeline.execute(ctx);

    expect(runCommand).toHaveBeenCalledWith("npx", ["hardhat", "test"], { cwd: projectRoot });
  });

  it("forwards passthrough arguments to the framework", async () => {
    await fs.writeFile(path.join(projectRoot, "foundry.toml"), "", "utf8");
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;
    ctx.param.passthrough = ["--match-test", "test_Increment", "-vvv"];

    await TestPipeline.execute(ctx);

    expect(runCommand).toHaveBeenCalledWith(
      "forge",
      ["test", "--match-test", "test_Increment", "-vvv"],
      { cwd: projectRoot },
    );
  });

  it("resolves the project root from a nested directory", async () => {
    const nestedDirectory = path.join(projectRoot, "src", "facets");
    await fs.mkdir(nestedDirectory, { recursive: true });
    await fs.writeFile(path.join(projectRoot, "foundry.toml"), "", "utf8");
    await fs.writeFile(
      path.join(projectRoot, "compose.json"),
      JSON.stringify({ framework: "foundry" }),
      "utf8",
    );
    const ctx = Context.create();
    ctx.param.projectRoot = nestedDirectory;

    await TestPipeline.execute(ctx);

    expect(runCommand).toHaveBeenCalledWith("forge", ["test"], { cwd: projectRoot });
  });

  it("fails when no supported framework is detected", async () => {
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;

    await expect(TestPipeline.execute(ctx)).rejects.toThrow("No supported framework detected");
    expect(runCommand).not.toHaveBeenCalled();
  });
});
