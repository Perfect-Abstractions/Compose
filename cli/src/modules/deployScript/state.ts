import type { ComposeContext, ModuleState } from "../../context/types";
import type { DeployProject } from "./types";

/** Read the deployment project prepared by this module. */
export function getDeployProject(ctx: ComposeContext): DeployProject {
  const state = ctx.state.deployProject as ModuleState<DeployProject> | undefined;
  if (!state?.success || !state.result) {
    throw new Error("Load the deployment project before generating a script.");
  }
  return state.result;
}
