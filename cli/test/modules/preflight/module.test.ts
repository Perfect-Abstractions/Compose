import { beforeEach, describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";

const { isBinaryInPath } = vi.hoisted(() => ({
  isBinaryInPath: vi.fn(async () => undefined),
}));

vi.mock("../../../src/utils/exec", () => ({ isBinaryInPath }));

import { PreflightModule } from "../../../src/modules/preflight/module";

/** Tests framework toolchain requirements without reading the host PATH. */
describe("PreflightModule", () => {
  beforeEach(() => {
    isBinaryInPath.mockClear();
  });

  it("requires forge for Foundry", async () => {
    const ctx = Context.create();
    ctx.param.framework = "foundry";

    await expect(PreflightModule.check(ctx)).resolves.toBe(ctx);
    expect(isBinaryInPath).toHaveBeenCalledWith("forge");
  });

  it("requires npm when Hardhat dependencies will be installed", async () => {
    const ctx = Context.create();
    ctx.param.framework = "hardhat";
    ctx.param.installDeps = true;

    await PreflightModule.check(ctx);
    expect(isBinaryInPath).toHaveBeenCalledWith("npm");
  });

  it("skips npm when Hardhat dependency installation is disabled", async () => {
    const ctx = Context.create();
    ctx.param.framework = "hardhat";
    ctx.param.installDeps = false;

    await PreflightModule.check(ctx);
    expect(isBinaryInPath).not.toHaveBeenCalled();
  });
});
