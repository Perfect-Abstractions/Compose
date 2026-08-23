import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { ComposeContext } from "../../../src/context/types";
import { Context } from "../../../src/context/context";

export type ValidatePipelineHarness = {
  ctx: ComposeContext;
  projectRoot: string;
  cleanup(): Promise<void>;
};

const facets = [
  "FullStorageFacet",
  "CompatibleStorageFacet",
  "IncompatibleStorageFacet",
];

/** Creates a Foundry project containing compatible and incompatible storage facets. */
export async function createValidatePipelineHarness(): Promise<ValidatePipelineHarness> {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-validate-pipeline-"));
  const sourceRoot = path.join(projectRoot, "src");
  const fixtureRoot = path.join(__dirname, "fixtures");
  const ctx = Context.create();

  await fs.mkdir(sourceRoot, { recursive: true });
  await Promise.all(facets.map((facet) => fs.copyFile(
    path.join(fixtureRoot, `${facet}.sol`),
    path.join(sourceRoot, `${facet}.sol`),
  )));
  await fs.writeFile(
    path.join(projectRoot, "foundry.toml"),
    '[profile.default]\nsrc = "src"\nout = "out"\nsolc = "0.8.30"\n',
    "utf8",
  );
  await fs.writeFile(
    path.join(projectRoot, "compose.json"),
    JSON.stringify({
      framework: "foundry",
      diamonds: {
        StorageDiamond: {
          contract: "src/Diamond.sol:Diamond",
          facets: Object.fromEntries(facets.map((facet) => [facet, {
            source: "local",
            contract: `src/${facet}.sol:${facet}`,
          }])),
        },
      },
    }, null, 2),
    "utf8",
  );

  ctx.param.command = "validate";
  ctx.param.projectRoot = projectRoot;
  return {
    ctx,
    projectRoot,
    cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }),
  };
}
