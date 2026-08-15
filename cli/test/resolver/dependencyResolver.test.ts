import { describe, expect, it } from "vitest";
import { DependencyResolver } from "../../src/resolver/dependencyResolver";
import { DependencyKey } from "../../src/resolver/dependencyKey";

describe("DependencyResolver RPC dependency", () => {
  it("is registered and resolves chain configuration before connecting", async () => {
    await expect(DependencyResolver.resolve([{ key: DependencyKey.RPC, params: { projectRoot: "/path/that/does/not/exist" } }])).rejects.toMatchObject({
      code: "RPC_INVALID_CONFIGURATION",
    });
  });
});
