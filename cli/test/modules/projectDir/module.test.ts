import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { Context } from "../../../src/context/context";
import { ProjectDirModule } from "../../../src/modules/projectDir/module";

/** Tests project path resolution and empty-directory protection. */
describe("ProjectDirModule", () => {
  it("resolves and creates a new project directory", async () => {
    const outputRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-project-dir-"));
    const ctx = Context.create();
    ctx.param.outDir = outputRoot;
    ctx.param.projectName = "example";

    try {
      await ProjectDirModule.resolve(ctx);
      await ProjectDirModule.validate(ctx);

      const expected = path.join(outputRoot, "example");
      expect(ctx.param.projectRoot).toBe(expected);
      await expect(fs.access(expected)).resolves.toBeUndefined();
    } finally {
      await fs.rm(outputRoot, { recursive: true, force: true });
    }
  });

  it("allows an existing directory containing only .git", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-project-dir-git-"));
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;

    try {
      await fs.mkdir(path.join(projectRoot, ".git"));
      await expect(ProjectDirModule.validate(ctx)).resolves.toBe(ctx);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });

  it("rejects a non-empty target directory", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-project-dir-full-"));
    const ctx = Context.create();
    ctx.param.projectRoot = projectRoot;

    try {
      await fs.writeFile(path.join(projectRoot, "existing.txt"), "occupied", "utf8");
      await expect(ProjectDirModule.validate(ctx)).rejects.toThrow(
        `Target directory is not empty: ${projectRoot}`,
      );
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });
});
