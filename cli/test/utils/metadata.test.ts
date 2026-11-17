import { readFile } from "node:fs/promises";
import { describe, expect, it } from "vitest";
import {
  getCliDependencySpec,
  VERSION,
} from "../../src/utils/metadata";

describe("CLI metadata", () => {
  it("uses the CLI package.json version as its version source", async () => {
    const packageJson = JSON.parse(
      await readFile(new URL("../../package.json", import.meta.url), "utf8"),
    ) as { version: string };

    expect(VERSION).toBe(packageJson.version);
    expect(getCliDependencySpec(VERSION)).toBe(`^${packageJson.version}`);
  });

  it("allows smoke tests to install the CLI from the checkout", () => {
    expect(getCliDependencySpec("0.4.0", "file:../cli")).toBe("file:../cli");
  });
});
