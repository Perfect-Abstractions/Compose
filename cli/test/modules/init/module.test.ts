import { beforeEach, describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { ComposeContext } from "../../../src/context/types";
import { ConfigModule } from "../../../src/modules/config/module";
import { InitModule } from "../../../src/modules/init/module";

async function createContext(param: Record<string, unknown>): Promise<ComposeContext> {
  const ctx = Context.create();
  Object.assign(ctx.param, param);
  await ConfigModule.loadBasesCatalog(ctx);
  return ctx;
}

/** Tests non-interactive init flag validation and normalized selection state. */
describe("InitModule.runInitNonInteractive", () => {
  let ctx: ComposeContext;

  beforeEach(async () => {
    ctx = await createContext({
      yes: true,
      framework: "foundry",
      base: "erc-20",
      projectName: "token-diamond",
    });
  });

  it("normalizes base, library, extension, ownership, and access selections", async () => {
    Object.assign(ctx.param, {
      libraries: "ERC165Facet",
      extensions: "ERC20BurnFacet",
      ownership: "owner",
      ownershipExtensions: "OwnerRenounceFacet",
      accessControl: "access-control",
      accessControlExtensions: "AccessControlGrantBatchFacet",
    });

    const result = await InitModule.runInitNonInteractive(ctx);

    expect(result).toBe(ctx);
    expect(result.param.libraries).toEqual(["ERC165Facet"]);
    expect(result.param.extensions).toEqual(["ERC20BurnFacet"]);
    expect(result.param.access).toEqual(["owner", "access-control"]);
    expect(result.param.accessExtensions).toEqual([
      "OwnerRenounceFacet",
      "AccessControlGrantBatchFacet",
    ]);
    expect(result.state.entry?.success).toBe(true);
    expect(result.state.entry?.result).toEqual(expect.objectContaining({
      framework: "foundry",
      selectedBaseKey: "erc-20",
      upgradeable: false,
      selectedLibraries: ["ERC165Facet"],
      selectedExtensions: ["ERC20BurnFacet"],
      selectedAccess: ["owner", "access-control"],
    }));
  });

  it("defaults to an immutable diamond without owner coupling", async () => {
    const logs = vi.spyOn(console, "log").mockImplementation(() => undefined);

    try {
      const result = await InitModule.runInitNonInteractive(ctx);

      expect(result.param.libraries).toEqual([]);
      expect(result.param.access).toEqual([]);
      expect(result.state.entry?.result).toEqual(expect.objectContaining({
        upgradeable: false,
        selectedLibraries: [],
        selectedAccess: [],
      }));
      expect(logs).not.toHaveBeenCalled();
    } finally {
      logs.mockRestore();
    }
  });

  it("adds the upgrade facet and owner coupling with --upgradeable", async () => {
    const logs = vi.spyOn(console, "log").mockImplementation(() => undefined);
    ctx.param.upgradeable = true;

    try {
      const result = await InitModule.runInitNonInteractive(ctx);

      expect(result.param.libraries).toEqual(["DiamondUpgradeFacet"]);
      expect(result.param.access).toEqual(["owner"]);
      expect(result.state.entry?.result).toEqual(expect.objectContaining({
        upgradeable: true,
        selectedLibraries: ["DiamondUpgradeFacet"],
        selectedAccess: ["owner"],
      }));
      expect(logs.mock.calls.flat().join("\n")).toContain("Upgradeable diamonds need an owner");
    } finally {
      logs.mockRestore();
    }
  });

  it("omits the upgrade facet and owner coupling when --immutable is set", async () => {
    ctx.param.immutable = true;

    const result = await InitModule.runInitNonInteractive(ctx);

    expect(result.param.libraries).toEqual([]);
    expect(result.param.access).toEqual([]);
    expect(result.state.entry?.result).toEqual(expect.objectContaining({ upgradeable: false }));
  });

  it("keeps an explicitly selected ownership base", async () => {
    ctx.param.ownership = "owner-two-step";

    const result = await InitModule.runInitNonInteractive(ctx);

    expect(result.param.access).toEqual(["owner-two-step"]);
    expect(result.param.libraries).toEqual([]);
  });

  it("does not add an owner when the base itself is an ownership base", async () => {
    ctx.param.base = "owner";
    ctx.param.upgradeable = true;

    const result = await InitModule.runInitNonInteractive(ctx);

    expect(result.param.access).toEqual([]);
    expect(result.param.libraries).toEqual(["DiamondUpgradeFacet"]);
  });

  it("honors an explicit DiamondUpgradeFacet library as upgradeable", async () => {
    const logs = vi.spyOn(console, "log").mockImplementation(() => undefined);
    ctx.param.libraries = "DiamondUpgradeFacet";

    try {
      const result = await InitModule.runInitNonInteractive(ctx);

      expect(result.param.libraries).toEqual(["DiamondUpgradeFacet"]);
      expect(result.param.access).toEqual(["owner"]);
      expect(result.state.entry?.result).toEqual(expect.objectContaining({ upgradeable: true }));
    } finally {
      logs.mockRestore();
    }
  });

  it("rejects --immutable with an explicit DiamondUpgradeFacet library", async () => {
    Object.assign(ctx.param, { immutable: true, libraries: "DiamondUpgradeFacet" });

    await expect(InitModule.runInitNonInteractive(ctx)).rejects.toThrow(
      "DiamondUpgradeFacet in --libraries conflicts with --immutable",
    );
  });

  it("rejects using --upgradeable and --immutable together", async () => {
    Object.assign(ctx.param, { upgradeable: true, immutable: true });

    await expect(InitModule.runInitNonInteractive(ctx)).rejects.toThrow(
      "Use either --upgradeable or --immutable, not both.",
    );
  });

  it("defaults Hardhat projects to the ethers toolbox", async () => {
    ctx.param.framework = "hardhat";

    await InitModule.runInitNonInteractive(ctx);

    expect(ctx.param.toolbox).toBe("ethers");
  });

  it.each([
    [{ base: undefined }, "Missing required flag: --base"],
    [{ base: "unknown" }, "Unknown base: unknown"],
    [{ framework: "truffle" }, "Unsupported framework: truffle"],
    [{ projectName: "invalid name" }, "Project name must not contain spaces"],
    [{ ownership: "owner,owner-two-step" }, "--ownership accepts only one ownership base"],
  ])("rejects invalid non-interactive parameters %#", async (override, message) => {
    Object.assign(ctx.param, override);

    await expect(InitModule.runInitNonInteractive(ctx)).rejects.toThrow(message);
  });
});
