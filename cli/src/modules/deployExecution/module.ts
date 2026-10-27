import fs from "node:fs/promises";
import path from "node:path";
import { isAddress, isHex, type Hex } from "viem";
import type { ComposeContext } from "../../context/types";
import type {
  BroadcastTransaction,
  IFrameworkAdapter,
} from "../../adapters/IFrameworkAdapter/interface";
import { runCommand } from "../../utils/exec";
import { toPassthroughArgs } from "../../utils/args";
import { toProjectRelativePath, writeFileIfMissing } from "../../utils/files";
import type { DeployPlan } from "../deployPlan/types";
import type { DeployExecutionResult, DeployResultFile } from "./types";
import { getIgnitionDeploymentId, HARDHAT_IGNITION_MODULE_ID } from "../deployScript/model";
import { parseIgnitionJournalTransactionHash } from "./ignitionJournal";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireAddress(value: unknown, label: string): Hex {
  if (typeof value !== "string" || !isAddress(value)) {
    throw new Error(`The deploy script reported an invalid ${label} address: ${String(value)}.`);
  }
  return value as Hex;
}

function toTransactionHash(value: unknown): Hex | null {
  return typeof value === "string" && isHex(value) && value.length === 66 ? (value as Hex) : null;
}

/** The framework's deploy result file, when it captures one. */
type DeployCapture = {
  /** Absolute path of the result file. */
  path: string;
  /** Project-relative path used in messages. */
  displayPath: string;
};

/** Resolves the active capture file for the adapter, or null when it uses a broadcast. */
function resolveCapture(adapter: IFrameworkAdapter, projectRoot: string): DeployCapture | null {
  const capturePath = adapter.getManagedDeployResultPath(projectRoot);
  if (!capturePath) return null;
  return { path: capturePath, displayPath: toProjectRelativePath(projectRoot, capturePath) };
}

/** Reads the result file when present; parse errors still fail hard. */
async function readOptionalResultFile(
  resultPath: string,
  displayPath: string,
): Promise<DeployResultFile | null> {
  let raw: string;
  try {
    raw = await fs.readFile(resultPath, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw new Error(`Unable to read ${displayPath}: ${(error as Error).message}`, { cause: error });
  }

  try {
    return JSON.parse(raw) as DeployResultFile;
  } catch (error) {
    throw new Error(`Unable to parse ${displayPath}: ${(error as Error).message}`, {
      cause: error,
    });
  }
}

/**
 * Validates a result file against the plan and extracts the deployment.
 *
 * Any mismatch (stale script, wrong chain, facet drift) fails hard so a
 * stale script can never be verified and recorded as current.
 *
 * @param raw - The parsed result file.
 * @param plan - The resolved deployment plan.
 * @param displayPath - Project-relative path of the result file, used in messages.
 * @returns The reported diamond and facet addresses.
 */
function validateResult(
  raw: DeployResultFile,
  plan: DeployPlan,
  displayPath: string,
): { diamond: Hex; facets: Record<string, Hex>; deployer?: Hex; ignitionDeploymentId?: string } {
  if (!isRecord(raw)) {
    throw new Error(`${displayPath} must contain a JSON object.`);
  }
  if (raw.mode !== "deploy") {
    throw new Error(`${displayPath} has an unexpected mode: ${String(raw.mode)}.`);
  }
  if (String(raw.planHash).toLowerCase() !== plan.planHash.toLowerCase()) {
    throw new Error(
      `${displayPath} was written by a different plan (plan hash mismatch). Re-run 'compose deploy' to regenerate the script.`,
    );
  }
  if (raw.chainId !== plan.chain.chainId) {
    throw new Error(
      `The deploy script targeted chain id ${String(raw.chainId)}; expected ${plan.chain.chainId}.`,
    );
  }
  if (raw.chainKey !== plan.chain.chainKey) {
    throw new Error(
      `The deploy script targeted chain '${String(raw.chainKey)}'; expected '${plan.chain.chainKey}'.`,
    );
  }
  if (raw.instance !== plan.instance) {
    throw new Error(
      `The deploy script targeted instance '${String(raw.instance)}'; expected '${plan.instance}'.`,
    );
  }
  if (raw.framework !== plan.framework) {
    throw new Error(
      `The deploy script ran under framework '${String(raw.framework)}'; expected '${plan.framework}'.`,
    );
  }

  let ignitionDeploymentId: string | undefined;
  if (plan.framework === "hardhat") {
    const expectedId = getIgnitionDeploymentId(plan);
    if (raw.ignitionDeploymentId !== expectedId) {
      throw new Error(
        `${displayPath} has an unexpected Hardhat Ignition deployment ID. Re-run 'compose deploy' to regenerate the runner.`,
      );
    }
    ignitionDeploymentId = expectedId;
  }

  const diamond = requireAddress(raw.diamond, "diamond");
  const deployer = typeof raw.deployer === "string"
    ? requireAddress(raw.deployer, "deployer")
    : undefined;
  if (plan.account && !deployer) {
    throw new Error(`${displayPath} is missing the selected account address.`);
  }
  if (plan.account && deployer?.toLowerCase() !== plan.account.address.toLowerCase()) {
    throw new Error(
      `The deploy script used signer ${deployer}; expected Compose account '${plan.account.alias}' at ${plan.account.address}.`,
    );
  }
  if (!isRecord(raw.facets)) {
    throw new Error(`${displayPath} is missing the facets object.`);
  }

  const desired = new Set(plan.facets.map((facet) => facet.name));
  const reported = new Set(Object.keys(raw.facets));
  const missing = [...desired].filter((name) => !reported.has(name));
  const unexpected = [...reported].filter((name) => !desired.has(name));
  if (missing.length > 0 || unexpected.length > 0) {
    throw new Error(
      `The deploy script reported facets that do not match the plan (missing: ${missing.join(", ") || "none"}; unexpected: ${unexpected.join(", ") || "none"}).`,
    );
  }

  const facets: Record<string, Hex> = {};
  for (const name of desired) {
    facets[name] = requireAddress(raw.facets[name], `facet '${name}'`);
  }
  return { diamond, facets, deployer, ...(ignitionDeploymentId ? { ignitionDeploymentId } : {}) };
}

/**
 * Derives the deployment from the framework's broadcast transactions.
 *
 * Used by frameworks that cannot write a result file (Foundry restricts
 * cheatcode file writes). Facet transactions are consumed in plan order;
 * the diamond is the last remaining matching deployment.
 */
function deriveFromBroadcast(
  broadcast: BroadcastTransaction[],
  plan: DeployPlan,
): { diamond: Hex; facets: Record<string, Hex>; txHash: Hex | null; deployer?: Hex } {
  const remaining = [...broadcast];
  const facets: Record<string, Hex> = {};

  for (const facet of plan.facets) {
    const index = remaining.findIndex((transaction) => transaction.contractName === facet.contractName);
    if (index === -1) {
      throw new Error(
        `The framework did not report a deployment for facet '${facet.name}' (${facet.contractName}). Re-run 'compose deploy --broadcast' and check the framework output.`,
      );
    }
    const [transaction] = remaining.splice(index, 1);
    facets[facet.name] = requireAddress(transaction.contractAddress, `facet '${facet.name}'`);
  }

  let diamondIndex = -1;
  for (let index = remaining.length - 1; index >= 0; index -= 1) {
    if (remaining[index].contractName === plan.diamond.contractName) {
      diamondIndex = index;
      break;
    }
  }
  if (diamondIndex === -1) {
    throw new Error(
      `The framework did not report a deployment of '${plan.diamond.contractName}'. Re-run 'compose deploy --broadcast' and check the framework output.`,
    );
  }

  const diamondTransaction = remaining[diamondIndex];
  const deployer = typeof diamondTransaction.from === "string"
    ? requireAddress(diamondTransaction.from, "deployer")
    : undefined;
  if (plan.account && !deployer) {
    throw new Error("The Foundry broadcast did not report the deployer address for the selected Compose account.");
  }
  if (plan.account && deployer?.toLowerCase() !== plan.account.address.toLowerCase()) {
    throw new Error(
      `Foundry broadcast signer ${deployer} does not match Compose account '${plan.account.alias}' at ${plan.account.address}.`,
    );
  }
  return {
    diamond: requireAddress(diamondTransaction.contractAddress, "diamond"),
    facets,
    txHash: toTransactionHash(diamondTransaction.txHash),
    deployer,
  };
}

/**
 * Deploy execution module.
 *
 * Runs the managed script under the framework, then normalizes the
 * deployment from the script's result file (Hardhat) or the framework's
 * broadcast transactions (Foundry). Framework output goes to the inherited
 * stdio, so signing and network prompts stay in the framework's hands.
 */
export const DeployExecutionModule = {
  /**
   * Executes the managed deploy script and normalizes its result.
   *
   * Stores the result in `ctx.state.deployExecution` on success and records a
   * failure state before rethrowing.
   *
   * @param ctx - The compose context with passthrough arguments.
   * @param plan - The resolved deployment plan.
   * @param scriptPath - Absolute path of the managed script to run.
   * @param adapter - The framework adapter building the command.
   * @returns The context with `state.deployExecution` populated.
   * @throws {Error} If the framework command fails or the result is invalid.
   */
  async execute(
    ctx: ComposeContext,
    plan: DeployPlan,
    scriptPath: string,
    adapter: IFrameworkAdapter,
    runnerPath: string | null = adapter.getManagedDeployRunnerPath(plan.projectRoot),
  ): Promise<ComposeContext> {
    const projectRoot = plan.projectRoot;
    const capture = resolveCapture(adapter, projectRoot);

    try {
      if (capture) {
        await writeFileIfMissing(
          path.join(path.dirname(capture.path), ".gitignore"),
          `${path.basename(capture.path)}\n`,
        );
        await fs.rm(capture.path, { force: true });
      }

      const command = adapter.createDeployCommand({
        chainId: plan.chain.chainId,
        chainKey: plan.chain.chainKey,
        passthrough: toPassthroughArgs(ctx.param.passthrough),
        projectRoot,
        rpcUrl: plan.chain.rpcUrl,
        account: plan.account,
        scriptPath,
        runnerPath,
        mode: "broadcast",
      });
      await runCommand(command.command, command.args, {
        cwd: projectRoot,
        ...(command.env ? { env: command.env } : {}),
      });

      const rawResult = capture
        ? await readOptionalResultFile(capture.path, capture.displayPath)
        : null;
      const broadcast = await adapter.readBroadcastTransactions(
        projectRoot,
        scriptPath,
        plan.chain.chainId,
      );

      let diamond: Hex;
      let facets: Record<string, Hex>;
      let deployer: Hex | undefined;
      let diamondTxHash: Hex | null;
      let ignitionDeploymentId: string | undefined;
      if (rawResult && capture) {
        const validated = validateResult(rawResult, plan, capture.displayPath);
        ({ diamond, facets, deployer, ignitionDeploymentId } = validated);
        if (plan.framework === "hardhat") {
          const hardhatDeploymentId = getIgnitionDeploymentId(plan);
          const journalPath = path.join(
            projectRoot,
            "ignition",
            "deployments",
            hardhatDeploymentId,
            "journal.jsonl",
          );
          let journal: string;
          try {
            journal = await fs.readFile(journalPath, "utf8");
          } catch (error) {
            throw new Error(
              `Unable to read Hardhat Ignition journal for deployment '${hardhatDeploymentId}': ${(error as Error).message}`,
              { cause: error },
            );
          }
          diamondTxHash = parseIgnitionJournalTransactionHash(
            journal,
            `${HARDHAT_IGNITION_MODULE_ID}#Diamond`,
          );
        } else {
          diamondTxHash = toTransactionHash(
            isRecord(rawResult.transactions) ? rawResult.transactions.diamond : undefined,
          );
        }
      } else {
        if (plan.framework === "hardhat") {
          throw new Error(
            `Hardhat did not write the managed deploy result at ${capture?.displayPath ?? "the configured result path"}.`,
          );
        }
        const derived = deriveFromBroadcast(broadcast, plan);
        diamond = derived.diamond;
        facets = derived.facets;
        deployer = derived.deployer;
        diamondTxHash = derived.txHash;
      }

      if (plan.framework === "foundry") {
        diamondTxHash ??= toTransactionHash(
          broadcast.find((transaction) => transaction.contractName === plan.diamond.contractName)?.txHash,
        );
      }
      if (!diamondTxHash) {
        throw new Error(
          "No diamond deployment transaction was recorded. Re-run 'compose deploy --broadcast' and check the framework output.",
        );
      }

      const result: DeployExecutionResult = {
        diamond,
        facets,
        ...(deployer ? { deployer } : {}),
        ...(ignitionDeploymentId ? { ignitionDeploymentId } : {}),
        transactions: { diamond: diamondTxHash },
      };
      ctx.state.deployExecution = { success: true, result, error: null };
      return ctx;
    } catch (error) {
      ctx.state.deployExecution = {
        success: false,
        result: null,
        error: {
          code: "DEPLOY_EXECUTION_FAILED",
          message: error instanceof Error ? error.message : "Deployment failed.",
          nativeError: error,
        },
      };
      throw error;
    } finally {
      if (plan.framework === "hardhat" && runnerPath) {
        try {
          await fs.rm(runnerPath, { force: true });
        } catch {
          // Do not convert a completed broadcast into a failure because cleanup failed.
        }
      }
    }
  },
};
