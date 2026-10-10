import { describe, expect, it, vi } from "vitest";
import { Context } from "../../../src/context/context";
import { PipelineBuilderModule } from "../../../src/modules/pipelineBuilder/module";
import { ValidatePipeline } from "../../../src/pipelines/validatePipeline";
import { SelectorsPipeline } from "../../../src/pipelines/selectorsPipeline";
import { HistoryPipeline } from "../../../src/pipelines/historyPipeline";

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

  it("routes the selectors command to SelectorsPipeline", async () => {
    const ctx = Context.create();
    ctx.param = { command: "selectors", address: "0x0000000000000000000000000000000000000001", chain: "local" };
    const execute = vi.spyOn(SelectorsPipeline, "execute").mockResolvedValue(ctx);

    try {
      const result = await PipelineBuilderModule.route(ctx);
      expect(result).toBe(ctx);
      expect(execute).toHaveBeenCalledWith(ctx);
      expect(ctx.state.commandSelected).toMatchObject({ success: true, result: ctx.param });
    } finally {
      execute.mockRestore();
    }
  });

  it("routes history to HistoryPipeline", async () => {
    const ctx = Context.create();
    ctx.param = { command: "history", address: "0x0000000000000000000000000000000000000001", chain: "local" };
    const execute = vi.spyOn(HistoryPipeline, "execute").mockResolvedValue(ctx);
    try {
      await PipelineBuilderModule.route(ctx);
      expect(execute).toHaveBeenCalledWith(ctx);
      expect(ctx.state.commandSelected).toMatchObject({ success: true, result: ctx.param });
    } finally {
      execute.mockRestore();
    }
  });
});
