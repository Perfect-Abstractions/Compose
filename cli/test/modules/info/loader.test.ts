import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { Context } from "../../../src/context/context";
import { loadComposeJson } from "../../../src/modules/info/loader";

describe("info compose.json loader", () => {
  it("stores a missing-file failure without throwing", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-info-loader-missing-"));

    try {
      const ctx = Context.create();
      ctx.param.projectRoot = root;

      await expect(loadComposeJson(ctx)).resolves.toBe(ctx);
      expect(ctx.state.infoLoader).toMatchObject({
        success: false,
        result: null,
        error: {
          code: "COMPOSE_JSON_NOT_FOUND",
          message: "compose.json not found. Run 'compose init' first or navigate to a Compose project directory.",
        },
      });
    } finally {
      await fs.rm(root, { recursive: true, force: true });
    }
  });

  it("loads the nearest file without changing the caller's project parameters", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-info-loader-"));

    try {
      const nestedDirectory = path.join(root, "src", "facets");
      await fs.mkdir(nestedDirectory, { recursive: true });
      await fs.writeFile(path.join(root, "compose.json"), JSON.stringify({ project: "example" }), "utf8");

      const ctx = Context.create();
      ctx.param.projectRoot = nestedDirectory;

      await loadComposeJson(ctx);

      expect(ctx.config.composeJson).toEqual({ project: "example" });
      expect(ctx.param.projectRoot).toBe(nestedDirectory);
      expect(ctx.param.framework).toBeUndefined();
      expect(ctx.state.infoLoader).toMatchObject({
        success: true,
        result: {
          composeJsonPath: path.join(root, "compose.json"),
          composeJson: { project: "example" },
        },
        error: null,
      });
    } finally {
      await fs.rm(root, { recursive: true, force: true });
    }
  });

  it("lets JSON parse errors propagate without setting loader state", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-info-loader-invalid-"));

    try {
      await fs.writeFile(path.join(root, "compose.json"), "{invalid", "utf8");
      const ctx = Context.create();
      ctx.param.projectRoot = root;

      await expect(loadComposeJson(ctx)).rejects.toBeInstanceOf(SyntaxError);
      expect(ctx.state.infoLoader).toBeUndefined();
    } finally {
      await fs.rm(root, { recursive: true, force: true });
    }
  });
});
