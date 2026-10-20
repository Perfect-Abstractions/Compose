import path from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { showSuccess } from "../../../src/modules/init/output";

describe("init success output", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("prints the path relative to the current directory when --out is elsewhere", () => {
    const projectRoot = path.resolve(process.cwd(), "..", "generated-projects", "my-diamond");
    const ctx = Context.create();
    ctx.param = {
      projectName: "my-diamond",
      projectRoot,
      framework: "foundry",
    };
    const log = vi.spyOn(console, "log").mockImplementation(() => undefined);

    showSuccess(ctx);

    expect(log.mock.calls.flat().join("\n")).toContain('cd "../generated-projects/my-diamond"');
  });

  it("omits the directory change when already in the project directory", () => {
    const ctx = Context.create();
    ctx.param = {
      projectName: "my-diamond",
      projectRoot: process.cwd(),
      framework: "foundry",
    };
    const log = vi.spyOn(console, "log").mockImplementation(() => undefined);

    showSuccess(ctx);

    expect(log.mock.calls.flat().join("\n")).not.toContain("cd ");
    expect(log.mock.calls.flat().join("\n")).toContain("npx compose test");
  });
});
