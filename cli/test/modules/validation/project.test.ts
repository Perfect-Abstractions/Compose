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

      expect(project.diamonds).toEqual([
        {
          name: "Example",
          sourcePath: path.join(projectRoot, "src", "Diamond.sol"),
          facets: [{
            contractName: "CounterFacet",
            sourcePath: path.join(projectRoot, "src", "facets", "CounterFacet.sol"),
          }],
        },
      ]);
      expect(project.diamondSourcePaths).toEqual([
        path.join(projectRoot, "src", "Diamond.sol"),
      ]);
      expect(project.facetSources).toEqual([
        {
          contractName: "CounterFacet",
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

  it("preserves facet ownership for each diamond", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-validation-scopes-"));
    const ctx = Context.create();

    try {
      await fs.writeFile(
        path.join(projectRoot, "compose.json"),
        JSON.stringify({
          framework: "foundry",
          diamonds: {
            Alpha: {
              contract: "src/Alpha.sol:Alpha",
              facets: {
                AlphaFacet: {
                  source: "local",
                  contract: "src/AlphaFacet.sol:AlphaFacet",
                },
              },
            },
            Beta: {
              contract: "src/Beta.sol:Beta",
              facets: {
                BetaFacet: {
                  source: "local",
                  contract: "src/BetaFacet.sol:BetaFacet",
                },
              },
            },
          },
        }),
        "utf8",
      );
      ctx.param.projectRoot = projectRoot;

      const project = await loadValidationProject(ctx);

      expect(project.diamonds).toEqual([
        {
          name: "Alpha",
          sourcePath: path.join(projectRoot, "src", "Alpha.sol"),
          facets: [{
            contractName: "AlphaFacet",
            sourcePath: path.join(projectRoot, "src", "AlphaFacet.sol"),
          }],
        },
        {
          name: "Beta",
          sourcePath: path.join(projectRoot, "src", "Beta.sol"),
          facets: [{
            contractName: "BetaFacet",
            sourcePath: path.join(projectRoot, "src", "BetaFacet.sol"),
          }],
        },
      ]);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });

  it("preserves source identity for duplicate contract names", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-validation-identity-"));
    const ctx = Context.create();

    try {
      await fs.writeFile(
        path.join(projectRoot, "compose.json"),
        JSON.stringify({
          framework: "foundry",
          diamonds: {
            Example: {
              contract: "src/Diamond.sol:Diamond",
              facets: {
                fooA: { source: "local", contract: "src/a/Foo.sol:Foo" },
                fooB: { source: "local", contract: "src/b/Foo.sol:Foo" },
              },
            },
          },
        }),
        "utf8",
      );
      ctx.param.projectRoot = projectRoot;

      const project = await loadValidationProject(ctx);
      const expectedFacets = [
        { contractName: "Foo", sourcePath: path.join(projectRoot, "src", "a", "Foo.sol") },
        { contractName: "Foo", sourcePath: path.join(projectRoot, "src", "b", "Foo.sol") },
      ];

      expect(project.facetSources).toEqual(expectedFacets);
      expect(project.diamonds[0].facets).toEqual(expectedFacets);
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
        { contractName: "PackageFacet", sourcePath: packageFacetPath },
      ]);
    } finally {
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });
});
