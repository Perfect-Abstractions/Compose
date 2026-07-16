import fs from "node:fs/promises";
import path from "node:path";
import { ComposeContext } from "../../context/types";
import {
  renderFoundryDeployScript,
  renderHardhatEthersDeployScript,
  renderHardhatViemDeployScript,
} from "./renderers";
import { resolveDeployGenerationModel } from "./model";

/**
 * Module responsible for generating framework-specific deploy scripts.
 */
export const DeployGenerationModule = {
  /**
   * Generates a deploy script for the selected framework and toolbox,
   * writes it to disk, and updates the compose context state.
   *
   * @param ctx - The compose context with project parameters and state.
   * @param scriptRoot - Directory where the deploy script will be written.
   * @returns The updated compose context with generation results.
   * @throws {Error} If the framework is unsupported or file operations fail.
   */
  async generateDeployScript(
    ctx: ComposeContext,
    scriptRoot: string,
  ): Promise<ComposeContext> {
    const framework = String(ctx.param.framework ?? "foundry");
    const toolbox = String(ctx.param.toolbox ?? "ethers");
    const outputFileName = framework === "foundry" ? "Deploy.s.sol" : "deploy.ts";
    const model = resolveDeployGenerationModel(ctx, scriptRoot, outputFileName);
    let source: string;

    if (framework === "foundry") {
      source = await renderFoundryDeployScript(model);
    } else if (framework === "hardhat" && toolbox === "viem") {
      source = await renderHardhatViemDeployScript(model);
    } else if (framework === "hardhat") {
      source = await renderHardhatEthersDeployScript(model);
    } else {
      throw new Error(`Cannot generate deploy script: unsupported framework ${framework}.`);
    }

    await fs.mkdir(path.dirname(model.outputPath), { recursive: true });
    await fs.writeFile(model.outputPath, source, "utf8");

    ctx.state.generateDeployScript = {
      success: true,
      result: {
        outputPath: model.outputPath,
        facets: model.facets.map((facet) => ({
          facetName: facet.facetName,
          contractName: facet.contractName,
          importPath: facet.importPath,
          group: facet.group,
        })),
        framework,
        toolbox: framework === "hardhat" ? toolbox : null,
      },
      error: null,
    };

    return ctx;
  },
};
