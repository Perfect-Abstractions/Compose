import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  createBytecodeE2EHarness,
  type BytecodeE2EHarness,
} from "./bytecodeHarness";

describe.sequential("validate pipeline bytecode E2E", () => {
  let harness: BytecodeE2EHarness;

  beforeAll(async () => {
    harness = await createBytecodeE2EHarness();
  }, 120_000);

  afterAll(async () => {
    await harness?.cleanup();
  });

  it("accepts deployed bytecode when the local VSL is a compatible append", async () => {
    const projectRoot = await harness.createValidationProject("compatible");
    const result = await harness.runValidate(projectRoot);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).toBe(0);
    expect(output).toContain("Validation passed.");
    expect(output).not.toContain("Bytecode validation failed");
  }, 120_000);

  it("rejects deployed bytecode when the local VSL contradicts every canonical field", async () => {
    const projectRoot = await harness.createValidationProject("incompatible");
    const result = await harness.runValidate(projectRoot);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(result.code, output).not.toBe(0);
    expect(output).toContain("Bytecode validation failed");
    expect(output).toContain("compose.e2e.storage");
    expect(output).toContain("Expected:");
    expect(output).toContain("Observed:");
  }, 120_000);
});
