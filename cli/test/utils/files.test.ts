import path from "node:path";
import { describe, expect, it } from "vitest";
import { planImportClosureTargets } from "../../src/utils/files";

const root = path.resolve("/tmp", "plan-import-closure");
const templates = path.join(root, "templates", "import-review");
const projectSrc = path.join(root, "project", "src");
const seedSource = path.join(templates, "NestedImportFacet.sol");
const seedTarget = path.join(projectSrc, "facets", "NestedImportFacet.sol");
const seeds = [{ source: seedSource, target: seedTarget }];

describe("planImportClosureTargets", () => {
  it("maps seed files to their targets and preserves nested dependency structure", () => {
    const libFee = path.join(templates, "libraries", "LibFee.sol");
    const feeMod = path.join(templates, "mods", "FeeMod.sol");

    const planned = planImportClosureTargets(seeds, [seedSource, libFee, feeMod], projectSrc);

    expect(planned.get(path.resolve(seedSource))).toBe(seedTarget);
    expect(planned.get(path.resolve(libFee))).toBe(path.join(projectSrc, "facets", "libraries", "LibFee.sol"));
    expect(planned.get(path.resolve(feeMod))).toBe(path.join(projectSrc, "facets", "mods", "FeeMod.sol"));
  });

  it("resolves transitive dependencies relative to the seed that contains them", () => {
    const feeMath = path.join(templates, "libraries", "internal", "FeeMath.sol");

    const planned = planImportClosureTargets(seeds, [seedSource, feeMath], projectSrc);

    expect(planned.get(path.resolve(feeMath))).toBe(
      path.join(projectSrc, "facets", "libraries", "internal", "FeeMath.sol"),
    );
  });

  it("falls back to the fallback directory for dependencies outside every seed", () => {
    const sharedUtil = path.join(root, "templates", "shared", "Util.sol");

    const planned = planImportClosureTargets(seeds, [seedSource, sharedUtil], projectSrc);

    expect(planned.get(path.resolve(sharedUtil))).toBe(path.join(projectSrc, "Util.sol"));
  });

  it("anchors dependencies to a seed when multiple seeds exist", () => {
    const otherSeedSource = path.join(root, "templates", "other", "OtherFacet.sol");
    const otherSeedTarget = path.join(projectSrc, "facets", "OtherFacet.sol");
    const otherDep = path.join(root, "templates", "other", "helpers", "OtherHelper.sol");

    const planned = planImportClosureTargets(
      [...seeds, { source: otherSeedSource, target: otherSeedTarget }],
      [otherSeedSource, otherDep],
      projectSrc,
    );

    expect(planned.get(path.resolve(otherSeedSource))).toBe(otherSeedTarget);
    expect(planned.get(path.resolve(otherDep))).toBe(
      path.join(projectSrc, "facets", "helpers", "OtherHelper.sol"),
    );
  });
});
