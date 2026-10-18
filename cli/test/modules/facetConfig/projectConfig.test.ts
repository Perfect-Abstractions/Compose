import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { Context } from "../../../src/context/context";
import { loadComposeProject } from "../../../src/modules/facetConfig/projectConfig";

describe("facet config project loader", () => {
  it("validates the project and defaults omitted facet maps", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-facet-project-"));

    try {
      await fs.writeFile(path.join(root, "compose.json"), JSON.stringify({
        framework: "foundry",
        diamonds: { Example: { contract: "src/Diamond.sol:Diamond" } },
      }), "utf8");
      const ctx = Context.create();
      ctx.param.projectRoot = root;

      const project = await loadComposeProject(ctx);

      expect(project).toEqual({
        path: path.join(root, "compose.json"),
        root,
        config: {
          framework: "foundry",
          diamonds: {
            Example: { contract: "src/Diamond.sol:Diamond", facets: {} },
          },
        },
      });
      expect(ctx.param.projectRoot).toBe(root);
      expect(ctx.param.framework).toBe("foundry");
      expect(ctx.config.composeJson).toEqual(project.config);
      expect(ctx.state.facetProjectConfig).toMatchObject({
        success: true,
        result: { path: project.path, projectRoot: root },
        error: null,
      });
    } finally {
      await fs.rm(root, { recursive: true, force: true });
    }
  });

  it("wraps read and parse errors with the compose.json path and original cause", async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-facet-project-invalid-"));

    try {
      const composeJsonPath = path.join(root, "compose.json");
      await fs.writeFile(composeJsonPath, "{invalid", "utf8");
      const ctx = Context.create();
      ctx.param.projectRoot = root;

      await expect(loadComposeProject(ctx)).rejects.toMatchObject({
        message: expect.stringContaining(`Unable to parse ${composeJsonPath}:`),
        cause: expect.any(SyntaxError),
      });
    } finally {
      await fs.rm(root, { recursive: true, force: true });
    }
  });
});
