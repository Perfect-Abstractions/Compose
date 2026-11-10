import { beforeEach, describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { selectDiamond } from "../../../src/modules/facetConfig/selection";

const mocks = vi.hoisted(() => ({
  isInteractive: vi.fn(() => true),
  select: vi.fn(async () => "second"),
}));

vi.mock("../../../src/utils/inquirer", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../../src/utils/inquirer")>();
  return {
    ...actual,
    isInteractive: mocks.isInteractive,
    loadPrompts: async () => ({ select: mocks.select }),
  };
});

beforeEach(() => {
  mocks.isInteractive.mockReturnValue(true);
  mocks.select.mockReset().mockResolvedValue("second");
});

describe("selectDiamond", () => {
  it("uses an explicit diamond without prompting", async () => {
    const ctx = Context.create();
    ctx.param.diamond = "second";

    await expect(selectDiamond(ctx, ["first", "second"], "deploy")).resolves.toBe("second");
    expect(mocks.select).not.toHaveBeenCalled();
  });

  it("uses the only defined diamond without prompting", async () => {
    await expect(selectDiamond(Context.create(), ["only"], "deploy")).resolves.toBe("only");
    expect(mocks.select).not.toHaveBeenCalled();
  });

  it("prompts for an ambiguous diamond when prompting is allowed", async () => {
    await expect(selectDiamond(Context.create(), ["first", "second"], "install facets into"))
      .resolves.toBe("second");
    expect(mocks.select).toHaveBeenCalledOnce();
  });

  it("refuses to prompt when prompting is disabled", async () => {
    await expect(selectDiamond(Context.create(), ["first", "second"], "deploy", { allowPrompt: false }))
      .rejects.toThrow("Specify --diamond");
    expect(mocks.select).not.toHaveBeenCalled();
  });

  it("requires --diamond when the terminal is not interactive", async () => {
    mocks.isInteractive.mockReturnValue(false);

    await expect(selectDiamond(Context.create(), ["first", "second"], "deploy"))
      .rejects.toThrow("Specify --diamond");
    expect(mocks.select).not.toHaveBeenCalled();
  });
});
