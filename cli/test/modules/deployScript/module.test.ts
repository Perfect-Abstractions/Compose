import fs from "node:fs/promises";
import path from "node:path";
import { describe, expect, it, vi } from "vitest";
import { DeployScriptModule } from "../../../src/modules/deployScript/module";
import { getDeployProject } from "../../../src/modules/deployScript/state";
import { foundryAdapter } from "../../../src/adapters/IFrameworkAdapter/foundryAdapter/adapter";
import { createDeployModuleHarness, constructorSources } from "./harness";

describe("DeployScriptModule", () => {
  it("requires a selection for multi-diamond projects and rejects unknown chains or init configuration", async () => {
    const harness = await createDeployModuleHarness();
    try {
      delete harness.ctx.param.diamond;
      await expect(DeployScriptModule.loadProject(harness.ctx)).rejects.toThrow("Specify a diamond");
      harness.ctx.param.diamond = "Selected";
      harness.ctx.param.chain = "../outside";
      await expect(DeployScriptModule.loadProject(harness.ctx)).rejects.toThrow("Invalid deployment chain key");
      harness.ctx.param.chain = "missing";
      await expect(DeployScriptModule.loadProject(harness.ctx)).rejects.toThrow("Chain missing must be an object");
      harness.ctx.param.chain = "local";
      const diamonds = harness.config.diamonds as Record<string, Record<string, unknown>>;
      diamonds.Selected.init = { target: "something" };
      await harness.writeConfig();
      await expect(DeployScriptModule.loadProject(harness.ctx)).rejects.toThrow("init configuration is not supported");
    } finally { await harness.cleanup(); }
  });

  it("infers the only diamond and resolves the actual package contract rather than its config alias", async () => {
    const harness = await createDeployModuleHarness();
    try {
      delete (harness.config.diamonds as Record<string, unknown>).Unselected;
      delete harness.ctx.param.diamond;
      await harness.writeConfig();
      const result = await DeployScriptModule.loadProject(harness.ctx);
      expect(getDeployProject(result).diamondName).toBe("Selected");
      expect(getDeployProject(result).facets[1]).toMatchObject({ name: "PackageAlias", contractName: "PackageFacet", origin: "package" });
    } finally { await harness.cleanup(); }
  });

  it.each(["facet", "diamond"] as const)("rejects unsupported %s constructor arguments before writing a script", async (unsupported) => {
    const harness = await createDeployModuleHarness();
    try {
      await DeployScriptModule.loadProject(harness.ctx);
      const adapter = {
        ...foundryAdapter,
        compileAst: vi.fn().mockResolvedValue(constructorSources(getDeployProject(harness.ctx), unsupported)),
      };
      await expect(DeployScriptModule.checkContracts(harness.ctx, adapter)).rejects.toThrow("Unsupported constructor");
      await expect(fs.access(path.join(harness.projectRoot, "compose-scripts"))).rejects.toThrow();
    } finally { await harness.cleanup(); }
  });
});
