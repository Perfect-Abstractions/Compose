import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  createBytecodeUnavailableHarness,
  type BytecodeUnavailableHarness,
} from "./bytecodeUnavailableHarness";

describe.sequential("validate pipeline unavailable bytecode E2E", () => {
  let harness: BytecodeUnavailableHarness;

  beforeAll(async () => {
    harness = await createBytecodeUnavailableHarness();
    await harness.removeCanonicalFacetCode();
  }, 120_000);

  afterAll(async () => {
    await harness?.cleanup();
  });

  it("reports an introspection error without blocking when packed selectors cannot be read", async () => {
    const result = await harness.runValidate();
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(0);
    expect(output).toContain("Diamond introspection error");
    expect(output).toContain("RPC readContract failed");
    expect(output).toContain("Validation completed with warnings.");
    expect(output).not.toContain("Validation passed.");
    expect(output).not.toContain("Bytecode validation failed");
  }, 120_000);
});
