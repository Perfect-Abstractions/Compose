import fs from "node:fs/promises";
import type { Hex } from "viem";
import type { ComposeContext, ModuleState } from "../../context/types";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import type { IHashingAdapter } from "../../adapters/IHashingAdapter/interface";
import { atomicWriteFile } from "../../utils/files";
import type { DeployPlan } from "../deployPlan/types";
import { buildScriptModel } from "./model";
import {
  renderFoundryDeployScript,
  renderHardhatIgnitionModule,
  renderHardhatIgnitionRunner,
} from "./renderers";
import type { ManagedScriptModel } from "./types";

/**
 * Deploy script module.
 *
 * Builds, renders, and writes the CLI-managed framework script for a plan.
 * Script freshness is determined by hashing the complete rendered source and
 * the complete source on disk; the plan-hash header remains plan metadata.
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
      : renderHardhatIgnitionModule(model);
  },

  /** Renders the transient Hardhat runtime without changing the reviewable module. */
  async renderRunner(model: ManagedScriptModel): Promise<string> {
    if (model.framework !== "hardhat") {
      throw new Error("Only Hardhat deployments use a transient deploy runner.");
    }
    return renderHardhatIgnitionRunner(model);
  },

  /**
   * Renders and atomically writes the managed script to its target path.
   *
   * @param model - The managed script model.
   */
  async write(model: ManagedScriptModel): Promise<void> {
    const source = await DeployScriptModule.render(model);
    await DeployScriptModule.writeSource(model.outputPath, source);
  },

  /** Atomically writes the transient Hardhat runner. */
  async writeRunner(model: ManagedScriptModel): Promise<void> {
    if (!model.runnerPath) throw new Error("The Hardhat deployment runner path is missing.");
    await DeployScriptModule.writeSource(model.runnerPath, await DeployScriptModule.renderRunner(model));
  },

  /**
   * Atomically writes already-rendered script source.
   *
   * @param scriptPath - Absolute path of the managed script.
   * @param source - Complete rendered script source.
   */
  async writeSource(scriptPath: string, source: string): Promise<void> {
    await atomicWriteFile(scriptPath, source);
  },

  /**
   * Hashes the complete UTF-8 contents of the managed script on disk.
   *
   * @param scriptPath - Absolute path of the managed script.
   * @param hashing - Hashing adapter used for the expected script source.
   * @returns The script's content hash, or null when missing or unreadable.
   */
  async readScriptHash(scriptPath: string, hashing: IHashingAdapter): Promise<Hex | null> {
    try {
      const source = await fs.readFile(scriptPath, "utf8");
      return hashing.keccak256(source);
    } catch {
      return null;
    }
  },
};
