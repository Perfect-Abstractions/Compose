import path from "node:path";
import type { ComposeContext, ModuleState } from "../../context/types";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import type { IHashingAdapter } from "../../adapters/IHashingAdapter/interface";
import type { ValidationProject } from "../validation/project";
import type { ResolvedFacetSource } from "../validation/types";
import { selectDiamond } from "../facetConfig/selection";
import { resolveChainConfig } from "../../utils/chainConfig";
import { toPosixPath, toRelativeImport } from "../../utils/files";
import { VERSION } from "../../utils/metadata";
import { UPGRADE_FACET_NAME } from "../config/catalog";
import { LockFileModule } from "../lockFile/module";
import { DEFAULT_INSTANCE, type ComposeLock } from "../lockFile/types";
import { validateOptions } from "../../adapters/IRPCAdapter/validation";
import { resolveAccountProfile } from "../accounts/config";
import type { DeploymentAccount } from "../accounts/types";
import { computePlanHash } from "./hash";
import type { DeployPlan, PlannedFacet } from "./types";

const INSTANCE_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const RESERVED_INSTANCES = new Set(["__proto__", "constructor", "prototype"]);

type DiamondConfig = {
  contract?: unknown;
  facets?: Record<string, unknown>;
};

/**
 * Rejects instance names that cannot safely become compose.lock object keys.
 *
 * @param instance - The requested deployment instance name.
 * @throws {Error} If the instance is empty, malformed, or a reserved object key.
 */
export function assertValidInstance(instance: string): void {
  if (!INSTANCE_PATTERN.test(instance) || RESERVED_INSTANCES.has(instance)) {
    throw new Error(
      `Invalid deployment instance '${instance}'. Use letters, digits, '.', '_' or '-' and avoid reserved object keys.`,
    );
  }
}

/**
 * Resolves the import path for a facet source as seen from the managed script.
 *
 * Compose package files (under `node_modules/@perfect-abstractions/compose`
 * or `lib/Compose/src`) keep their package specifier; project files become
 * relative imports from the framework script root.
 *
 * @param sourcePath - Absolute path of the resolved facet source.
 * @param projectRoot - Absolute project root.
 * @param scriptRoot - Absolute directory holding the managed deploy script.
 * @returns The import specifier to use in the generated script.
 * @throws {Error} If the source is neither a package file nor inside the project.
 */
export function resolveFacetImportSpec(
  sourcePath: string,
  projectRoot: string,
  scriptRoot: string,
): string {
  const normalized = path.resolve(sourcePath);
  const composePackageRoots = [
    path.join(projectRoot, "node_modules", "@perfect-abstractions", "compose"),
    path.join(projectRoot, "lib", "Compose", "src"),
  ];
  for (const packageRoot of composePackageRoots) {
    const relative = path.relative(packageRoot, normalized);
    if (relative && !relative.startsWith("..") && !path.isAbsolute(relative)) {
      return `@perfect-abstractions/compose/${toPosixPath(relative)}`;
    }
  }

  const relativeToProject = path.relative(projectRoot, normalized);
  if (!relativeToProject || relativeToProject.startsWith("..") || path.isAbsolute(relativeToProject)) {
    throw new Error(
      `Facet source ${sourcePath} is outside the project and not a Compose package file. Fix its path in compose.json or reinstall the facet.`,
    );
  }
  return toRelativeImport(toPosixPath(path.relative(scriptRoot, normalized)));
}

/**
 * Pairs compose.json facet entries with their resolved sources, preserving
 * registration order and rejecting any mismatch.
 */
function zipFacets(
  diamondName: string,
  diamondConfig: DiamondConfig,
  resolvedFacets: ResolvedFacetSource[],
  projectRoot: string,
  scriptRoot: string,
): PlannedFacet[] {
  const configured = Object.entries(diamondConfig.facets ?? {});
  if (configured.length !== resolvedFacets.length) {
    throw new Error(
      `Diamond '${diamondName}' lists ${configured.length} facets in compose.json but ${resolvedFacets.length} sources were resolved.`,
    );
  }

  return configured.map(([name, entry], index) => {
    const resolved = resolvedFacets[index];
    const reference = typeof (entry as { contract?: unknown })?.contract === "string"
      ? String((entry as { contract: string }).contract)
      : "";
    const expectedName = reference.includes(":")
      ? reference.slice(reference.lastIndexOf(":") + 1)
      : name;
    if (resolved.contractName !== expectedName) {
      throw new Error(
        `Facet '${name}' resolved to '${resolved.contractName}' instead of '${expectedName}'. Check compose.json.`,
      );
    }

    return {
      name,
      contractName: resolved.contractName,
      sourcePath: resolved.sourcePath,
      importSpec: resolveFacetImportSpec(resolved.sourcePath, projectRoot, scriptRoot),
    };
  });
}

/**
 * Deploy plan module.
 *
 * Resolves the target diamond, chain, and instance against compose.json and
 * the existing compose.lock record, then produces the plan the script
 * generator and executor operate on. The plan is pure input parsing plus lock
 * comparison; it never touches the chain.
 */
export const DeployPlanModule = {
  /**
   * Builds the deployment plan for the selected diamond, chain, and instance.
   *
   * Stores the plan in `ctx.state.deployPlan`.
   *
   * @param ctx - The compose context with project parameters.
   * @param dependencies - The loaded validation project, framework adapter, and hashing adapter.
   * @returns The context with `state.deployPlan` populated.
   * @throws {Error} If the diamond, chain, or lock file cannot be resolved.
   */
  async resolve(
    ctx: ComposeContext,
    dependencies: {
      project: ValidationProject;
      adapter: IFrameworkAdapter;
      hashing: IHashingAdapter;
    },
  ): Promise<ComposeContext> {
    const { project, adapter, hashing } = dependencies;
    const projectRoot = String(ctx.param.projectRoot);
    const framework = String(ctx.param.framework) as DeployPlan["framework"];
    const diamondName = await selectDiamond(
      ctx,
      project.diamonds.map((diamond) => diamond.name),
      "deploy",
    );
    const diamond = project.diamonds.find((candidate) => candidate.name === diamondName);
    if (!diamond) {
      throw new Error(`Diamond '${diamondName}' was not resolved from compose.json.`);
    }

    const instance = String(ctx.param.instance ?? DEFAULT_INSTANCE);
    assertValidInstance(instance);

    const chain = await resolveChainConfig({
      chainKey: ctx.param.chain,
      projectRoot,
      rpcUrlOverride: ctx.param.rpcUrl,
    });
    validateOptions({ rpcUrl: chain.rpcUrl, chainId: chain.chainId });
    ctx.param.chainKey = chain.chainKey;

    const composeJson = ctx.config.composeJson as {
      accounts?: unknown;
      diamonds?: Record<string, DiamondConfig>;
    } | undefined;
    const accountAliasValue = ctx.param.account ?? chain.account;
    let account: DeploymentAccount | null = null;
    if (accountAliasValue !== undefined) {
      if (typeof accountAliasValue !== "string") {
        throw new Error("Account alias must be a string.");
      }
      account = resolveAccountProfile(composeJson?.accounts, accountAliasValue, framework);
    }

    const diamondConfig = composeJson?.diamonds?.[diamondName];
    if (!diamondConfig) {
      throw new Error(`Diamond '${diamondName}' is missing from compose.json.`);
    }
    const diamondReference = typeof diamondConfig.contract === "string" ? diamondConfig.contract : "";
    const referenceName = diamondReference.includes(":")
      ? diamondReference.slice(diamondReference.lastIndexOf(":") + 1)
      : "";
    const diamondContractName = referenceName || path.basename(diamond.sourcePath, ".sol");

    const scriptRoot = adapter.getScriptRoot(projectRoot);
    const facets = zipFacets(diamondName, diamondConfig, diamond.facets, projectRoot, scriptRoot);

    ctx = await LockFileModule.readLockFile(ctx);
    const lockState = ctx.state.lockFile as ModuleState<{ path: string; lock: ComposeLock } | null>;
    if (!lockState.success) {
      throw new Error(lockState.error?.message ?? "Failed to read compose.lock.");
    }
    const lock = lockState.result?.lock ?? LockFileModule.createEmptyLock(VERSION);
    const existing = LockFileModule.getDeployment(lock, diamondName, chain.chainKey, instance) ?? null;

    let mode: DeployPlan["mode"] = existing ? "in-sync" : "fresh";
    let diff: DeployPlan["diff"] = null;
    if (existing) {
      const desired = new Set(facets.map((facet) => facet.name));
      const deployed = new Set(Object.keys(existing.facets));
      const added = [...desired].filter((name) => !deployed.has(name));
      const removed = [...deployed].filter((name) => !desired.has(name));
      if (ctx.param.redeploy) {
        mode = "redeploy";
      } else if (added.length > 0 || removed.length > 0) {
        mode = "diff";
        diff = { added, removed };
      }
    }

    const validationState = ctx.state.validationProject as ModuleState<{ composeJsonPath: string }>;
    const planBase = {
      mode,
      framework,
      projectRoot,
      composeJsonPath: validationState?.result?.composeJsonPath ?? path.join(projectRoot, "compose.json"),
      diamondName,
      diamond: {
        contractName: diamondContractName,
        sourcePath: diamond.sourcePath,
        importSpec: resolveFacetImportSpec(diamond.sourcePath, projectRoot, scriptRoot),
      },
      instance,
      chain,
      rpcUrlOverridden: ctx.param.rpcUrl !== undefined,
      account,
      facets,
      existing,
      diff,
      upgradeable: facets.some((facet) => facet.name === UPGRADE_FACET_NAME),
    };
    const plan: DeployPlan = {
      ...planBase,
      planHash: computePlanHash(planBase, hashing),
    };

    ctx.state.deployPlan = { success: true, result: plan, error: null };
    return ctx;
  },
};
