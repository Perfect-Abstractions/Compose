import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { Context } from "../../../src/context/context";
import { loadValidationProject } from "../../../src/modules/validation/project";

describe("validation project loader", () => {
  it("loads framework and facet contract names from the nearest compose.json", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-validation-project-"));
    const nestedDirectory = path.join(projectRoot, "src", "facets");
    const ctx = Context.create();

    try {
      await fs.mkdir(nestedDirectory, { recursive: true });
      await fs.writeFile(
        path.join(projectRoot, "compose.json"),
        JSON.stringify({
          framework: "foundry",
          diamonds: {
            Example: {
              contract: "src/Diamond.sol:Diamond",
              facets: {
                counter: {
                  source: "local",
                  contract: "src/facets/CounterFacet.sol:CounterFacet",
                },
              },
            },
          },
        }),
        "utf8",
      );
      ctx.param.projectRoot = nestedDirectory;

      const project = await loadValidationProject(ctx);

      expect(project.facetNames).toEqual(["CounterFacet"]);
      expect(project.diamondSourcePaths).toEqual([
        path.join(projectRoot, "src", "Diamond.sol"),
      ]);
      expect(project.facetSources).toEqual([
        {
          facetName: "CounterFacet",
          sourcePath: path.join(projectRoot, "src", "facets", "CounterFacet.sol"),
        },
      ]);
      expect(ctx.param.projectRoot).toBe(projectRoot);
      expect(ctx.param.framework).toBe("foundry");
      expect(ctx.state.validationProject?.success).toBe(true);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });

  it("resolves package facets from the installed Compose dependency", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-validation-package-"));
    const packageFacetPath = path.join(
      projectRoot,
      "lib",
      "Compose",
      "src",
      "diamond",
      "PackageFacet.sol",
    );
    const ctx = Context.create();

    try {
      await fs.mkdir(path.dirname(packageFacetPath), { recursive: true });
      await fs.writeFile(packageFacetPath, "contract PackageFacet {}", "utf8");
      await fs.writeFile(
        path.join(projectRoot, "compose.json"),
        JSON.stringify({
          framework: "foundry",
          diamonds: {
            Example: {
              contract: "src/Diamond.sol:Diamond",
              facets: {
                PackageFacet: {
                  source: "package",
                  contract: "PackageFacet",
                  package: "@perfect-abstractions/compose",
                },
              },
            },
          },
        }),
        "utf8",
      );
      ctx.param.projectRoot = projectRoot;

      const project = await loadValidationProject(ctx);

      expect(project.facetSources).toEqual([
        { facetName: "PackageFacet", sourcePath: packageFacetPath },
      ]);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });
});
