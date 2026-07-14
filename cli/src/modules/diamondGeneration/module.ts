import fs from "node:fs/promises";
import path from "node:path";
import { ComposeContext } from "../../context/types";
import { copyFileIfMissing, findMissingFiles } from "../../utils/files";
import { renderDiamondContract } from "./renderer";
import { resolveDiamondGenerationModel } from "./model";
import { DiamondGenerationFile, DiamondImport } from "./types";

/**
 * Module responsible for generating the Diamond.sol proxy contract and
 * copying supporting files to the project source directory.
 */
export const DiamondGenerationModule = {
  /**
   * Generates the Diamond contract, copies supporting files, and updates
   * the compose context state with the results.
   *
   * @param ctx - The compose context with project parameters and state.
   * @param contractSourceRoot - Directory where Solidity source files live.
   * @returns The updated compose context with generation results.
   * @throws {Error} If source files are missing or file operations fail.
   */
  async generateDiamondContract(
    ctx: ComposeContext,
    contractSourceRoot: string,
  ): Promise<ComposeContext> {
    const model = resolveDiamondGenerationModel(ctx, contractSourceRoot);
    const missingFiles = await findMissingFiles(
      model.files.map((file: DiamondGenerationFile) => file.source),
    );

    if (missingFiles.length > 0) {
      throw new Error(`Cannot generate Diamond.sol: source files not found:\n${missingFiles.join("\n")}`);
    }

    for (const file of model.files) {
      await copyFileIfMissing(file.source, file.target);
    }

    const source = await renderDiamondContract(model);
    await fs.mkdir(path.dirname(model.outputPath), { recursive: true });
    await fs.writeFile(model.outputPath, source, "utf8");

    ctx.state.generateDiamondContract = {
      success: true,
      result: {
        outputPath: model.outputPath,
        copiedFiles: model.files.map((file: DiamondGenerationFile) => file.target),
        imports: model.imports.map((entry: DiamondImport) => entry.path),
        constructorEntries: model.constructorEntries,
        erc165Registrations: model.erc165Registrations.map((entry) => entry.id),
      },
      error: null,
    };

    return ctx;
  },
};
