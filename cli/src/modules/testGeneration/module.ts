import { ComposeContext } from "../../context/types";
import { resolveTestGenerationModel } from "./model";
import {
  renderFoundryTest,
  renderHardhatEthersTest,
  renderHardhatViemTest,
} from "./renderers";
import { writeFileIfMissing } from "../../utils/files";

/**
 * Module responsible for generating framework-specific Diamond test files.
 */
export const TestGenerationModule = {
  /**
   * Generates a test file for the selected framework and toolbox,
   * writes it to disk if missing, and updates the compose context state.
   *
   * @param ctx - The compose context with project parameters and state.
   * @param testRoot - Directory where the test file will be written.
   * @returns The updated compose context with generation results.
   * @throws {Error} If the framework is unsupported or file operations fail.
   */
  async generateTestFile(
    ctx: ComposeContext,
    testRoot: string,
  ): Promise<ComposeContext> {
    const framework = String(ctx.param.framework ?? "foundry");
    const toolbox = String(ctx.param.toolbox ?? "ethers");
    const outputFileName = framework === "foundry" ? "Diamond.t.sol" : "Diamond.ts";
    const model = resolveTestGenerationModel(ctx, testRoot, outputFileName);
    let source: string;

    if (framework === "foundry") {
      source = await renderFoundryTest(model);
    } else if (framework === "hardhat" && toolbox === "viem") {
      source = await renderHardhatViemTest(model);
    } else if (framework === "hardhat") {
      source = await renderHardhatEthersTest(model);
    } else {
      throw new Error(`Cannot generate test: unsupported framework ${framework}.`);
    }

    await writeFileIfMissing(model.outputPath, source);

    ctx.state.generateTestFile = {
      success: true,
      result: {
        outputPath: model.outputPath,
        facetCount: model.facetCount,
        framework,
        toolbox: framework === "hardhat" ? toolbox : null,
      },
      error: null,
    };

    return ctx;
  },
};
