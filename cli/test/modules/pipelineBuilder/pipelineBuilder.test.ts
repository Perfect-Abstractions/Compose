import { describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { PipelineBuilderModule } from "../../../src/modules/pipelineBuilder/module";
import { ValidatePipeline } from "../../../src/pipelines/validatePipeline";

describe("PipelineBuilderModule", () => {
  it("routes the validate command to ValidatePipeline", async () => {
    const ctx = Context.create();
    ctx.param.command = "validate";
    const execute = vi.spyOn(ValidatePipeline, "execute").mockResolvedValue(ctx);

    try {
      const result = await PipelineBuilderModule.route(ctx);

      expect(result).toBe(ctx);
      expect(execute).toHaveBeenCalledWith(ctx);
      expect(ctx.state.commandSelected?.success).toBe(true);
    } finally {
      execute.mockRestore();
    }
  });
});
