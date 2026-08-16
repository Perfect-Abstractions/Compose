import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { foundryAdapter } from "../../../../src/adapters/foundryAdapter";
import { canonicalizeAst } from "../canonicalAst";
import { createFoundryAdapterFixtureHarness } from "./harness";

/** Tests Foundry AST compilation and artifact normalization. */
describe("foundryAdapter.compileAst", () => {
  it(
    "generates and returns the expected Solidity AST",
    async () => {
      const harness = await createFoundryAdapterFixtureHarness();

      try {
        const artifactPath = path.join(harness.projectRoot, "out", "Normal.sol", "Normal.json");
        await expect(fs.access(artifactPath)).rejects.toThrow();

        const result = await foundryAdapter.compileAst(harness.ctx, [
          path.join(harness.projectRoot, "src", "Normal.sol"),
        ]);
        const normalSource = result.find((source) => source.sourceName === "src/Normal.sol");
        const expected = JSON.parse(
          await fs.readFile(
            path.join(__dirname, "..", "fixtures", "normal", "expected", "foundry.ast.json"),
            "utf8",
          ),
        );

        await expect(fs.access(artifactPath)).resolves.toBeUndefined();
        expect(normalSource?.ast.nodeType).toBe("SourceUnit");
        expect(canonicalizeAst(normalSource!.ast)).toEqual(expected);
      } finally {
        await harness.cleanup();
      }
    },
    30_000,
  );
});
