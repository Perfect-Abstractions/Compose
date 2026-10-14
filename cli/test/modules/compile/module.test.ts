import { describe, expect, it, vi } from "vitest";
import type { IFrameworkAdapter } from "../../../src/adapters/IFrameworkAdapter/interface";
import { CompileModule } from "../../../src/modules/compile/module";

describe("CompileModule.compileProject", () => {
  it("delegates incremental freshness checks to the framework compiler", async () => {
    const compile = vi.fn().mockResolvedValue(undefined);
    const adapter = { compile } as unknown as IFrameworkAdapter;

    await CompileModule.compileProject("/project", adapter);

    expect(compile).toHaveBeenCalledOnce();
    expect(compile).toHaveBeenCalledWith("/project");
  });
});
