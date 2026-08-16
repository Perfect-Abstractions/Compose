import fs from "node:fs/promises";
import path from "node:path";
import { beforeAll, describe, expect, it } from "vitest";
import { hardhatAdapter } from "../../../../src/adapters/hardhatAdapter";
import { canonicalizeAst } from "../canonicalAst";
import {
  createHardhatAdapterFixtureHarness,
  ensureHardhatFixtureDependencies,
} from "./harness";

/** Tests Hardhat AST compilation and build-info normalization. */
describe("hardhatAdapter.compileAst", () => {
  beforeAll(() => ensureHardhatFixtureDependencies(), 120_000);

  it(
    "generates and returns a fresh Solidity AST",
    async () => {
      const harness = await createHardhatAdapterFixtureHarness();

      try {
        const buildInfoRoot = path.join(harness.projectRoot, "artifacts", "build-info");
        await expect(fs.access(buildInfoRoot)).rejects.toThrow();

        const result = await hardhatAdapter.compileAst(harness.ctx, [
          path.join(harness.projectRoot, "contracts", "Normal.sol"),
        ]);
        const buildInfoFiles = await fs.readdir(buildInfoRoot);
        const normalSource = result.find(
          (source) => source.sourceName === "project/contracts/Normal.sol",
        );
        const expected = JSON.parse(
          await fs.readFile(
            path.join(__dirname, "..", "fixtures", "normal", "expected", "hardhat.ast.json"),
            "utf8",
          ),
        );

        expect(buildInfoFiles.some((file) => file.endsWith(".json"))).toBe(true);
        expect(normalSource?.ast.nodeType).toBe("SourceUnit");
        expect(normalSource?.ast.nodes).toEqual(
          expect.arrayContaining([
            expect.objectContaining({
              name: "Normal",
              nodeType: "ContractDefinition",
            }),
          ]),
        );
        expect(canonicalizeAst(normalSource!.ast)).toEqual(expected);
      } finally {
        await harness.cleanup();
      }
    },
    30_000,
  );
});
