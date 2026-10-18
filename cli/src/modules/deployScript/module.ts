import fs from "node:fs/promises";
import path from "node:path";
import type { ComposeContext } from "../../context/types";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import type { IHashingAdapter } from "../../adapters/IHashingAdapter/interface";
import type { FacetScanResult } from "../validation/types";
import {
  renderFoundryDeployScript, renderHardhatEthersDeployScript, renderHardhatViemDeployScript,
} from "../deployGeneration/renderers";
import { loadDeployProject } from "./project";
import { validateDeployConstructors } from "./contracts";
import { getDeployProject } from "./state";
import { buildDeployScriptModel, buildDeployScriptArtifact } from "./model";

export const DeployScriptModule = {
  async loadProject(ctx: ComposeContext): Promise<ComposeContext> {
    const project = await loadDeployProject(ctx);
    ctx.param.projectRoot = project.projectRoot;
    ctx.param.framework = project.framework;
    ctx.param.diamond = project.diamondName;
    ctx.state.deployProject = { success: true, result: project, error: null };
    return ctx;
  },

  async checkContracts(ctx: ComposeContext, adapter: IFrameworkAdapter): Promise<ComposeContext> {
    const project = getDeployProject(ctx);
    const sources = await adapter.compileAst(ctx, [project.diamond.sourcePath, ...project.facets.map((facet) => facet.sourcePath)]);
    validateDeployConstructors(project, sources);
    ctx.state.deployContracts = { success: true, result: { checkedContracts: project.facets.length + 1 }, error: null };
    return ctx;
  },

  async generate(ctx: ComposeContext, adapter: IFrameworkAdapter, hashing: IHashingAdapter, scans: FacetScanResult[]): Promise<ComposeContext> {
    if (!ctx.state.deployContracts?.success) throw new Error("Check deployment contracts before generating a script.");
    const project = getDeployProject(ctx);
    let toolbox: "ethers" | "viem" | null = null;
    if (project.framework === "hardhat") {
      if (ctx.param.toolbox !== undefined && ctx.param.toolbox !== "ethers" && ctx.param.toolbox !== "viem") {
        throw new Error("Hardhat toolbox must be ethers or viem.");
      }
      toolbox = ctx.param.toolbox as "ethers" | "viem" | undefined ?? await adapter.getDeploymentToolbox(project.projectRoot);
      if (!toolbox) throw new Error("Cannot determine the Hardhat deployment toolbox.");
    }
    const generatedAt = new Date().toISOString();
    const diamondReference = await adapter.getDeploymentContractReference(project.projectRoot, project.diamond.sourcePath, project.diamond.contractName);
    const facetReferences = await Promise.all(project.facets.map((facet) => adapter.getDeploymentContractReference(project.projectRoot, facet.sourcePath, facet.contractName)));
    const references = { diamond: diamondReference, facets: facetReferences };
    const model = buildDeployScriptModel(project, references, generatedAt);
    const source = project.framework === "foundry" ? await renderFoundryDeployScript(model)
      : toolbox === "viem" ? await renderHardhatViemDeployScript(model) : await renderHardhatEthersDeployScript(model);
    const artifact = buildDeployScriptArtifact(project, references, model, generatedAt, toolbox, scans, hashing);
    await fs.mkdir(path.dirname(model.outputPath), { recursive: true });
    await fs.writeFile(model.outputPath, source, { encoding: "utf8", flag: "wx" });
    ctx.state.deployScript = { success: true, result: artifact, error: null };
    return ctx;
  },
};
