import fs from "node:fs/promises";
import type { Hex } from "viem";
import type { ComposeContext, ModuleState } from "../../context/types";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import { atomicWriteFile } from "../../utils/files";
import type { DeployPlan } from "../deployPlan/types";
import { buildScriptModel } from "./model";
import { renderFoundryDeployScript, renderHardhatDeployScript } from "./renderers";
import type { ManagedScriptModel } from "./types";

const PLAN_HASH_LINE = /^\/\/\s*compose-plan-hash:\s*(0x[0-9a-fA-F]{64})\s*$/m;

/**
 * Deploy script module.
 *
 * Builds, renders, and writes the CLI-managed framework script for a plan.
 * The script carries the plan hash in its header so the executor can tell
 * whether a reviewed script still matches the current plan.
 */
export const DeployScriptModule = {
  /**
   * Builds the managed script model for the current plan.
   *
   * Stores the model and target path in `ctx.state.deployScript`.
   *
   * @param ctx - The compose context with `state.deployPlan` populated.
   * @param adapter - The framework adapter resolving script locations.
   * @returns The context with `state.deployScript` populated.
   * @throws {Error} If the deploy plan is missing.
   */
  async buildModel(ctx: ComposeContext, adapter: IFrameworkAdapter): Promise<ComposeContext> {
    const planState = ctx.state.deployPlan as ModuleState<DeployPlan> | undefined;
    if (!planState?.success || !planState.result) {
      throw new Error("Cannot generate the deploy script: the deploy plan is missing.");
    }

    const model = await buildScriptModel(planState.result, adapter);
    ctx.state.deployScript = {
      success: true,
      result: { path: model.outputPath, model },
      error: null,
    };
    return ctx;
  },

  /**
   * Renders the managed script source for a model.
   *
   * @param model - The managed script model.
   * @returns The complete script source.
   */
  async render(model: ManagedScriptModel): Promise<string> {
    return model.framework === "foundry"
      ? renderFoundryDeployScript(model)
      : renderHardhatDeployScript(model);
  },

  /**
   * Renders and atomically writes the managed script to its target path.
   *
   * @param model - The managed script model.
   */
  async write(model: ManagedScriptModel): Promise<void> {
    const source = await DeployScriptModule.render(model);
    await atomicWriteFile(model.outputPath, source);
  },

  /**
   * Reads the plan hash a managed script was generated from, if present.
   *
   * @param scriptPath - Absolute path of the managed script.
   * @returns The lowercase plan hash, or null when missing or unreadable.
   */
  async readPlanHash(scriptPath: string): Promise<Hex | null> {
    try {
      const source = await fs.readFile(scriptPath, "utf8");
      const match = source.match(PLAN_HASH_LINE);
      return match ? (match[1].toLowerCase() as Hex) : null;
    } catch {
      return null;
    }
  },
};
