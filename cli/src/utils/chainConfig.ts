import fs from "node:fs/promises";
import { findFileAncestor } from "./files";
import { RPCAdapterError } from "../adapters/rpc/errors";

export type ResolvedChainConfig = {
  /** Name used to select the chain in compose.json. */
  chainKey: string;
  /** RPC URL after environment-variable interpolation. */
  rpcUrl: string;
  /** Expected EVM chain ID for the selected endpoint. */
  chainId: number;
};

export type ResolveChainOptions = {
  /** Chain key; defaults to `local`. */
  chainKey?: unknown;
  /** Directory from which to search upward for compose.json. */
  projectRoot?: string;
};

const ENVIRONMENT_VARIABLE = /\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g;

function interpolateRPCUrl(value: string): string {
  const missing = new Set<string>();
  const resolved = value.replace(ENVIRONMENT_VARIABLE, (_, name: string) => {
    const environmentValue = process.env[name];
    if (!environmentValue) {
      missing.add(name);
      return "";
    }
    return environmentValue;
  });

  if (missing.size > 0) {
    throw new RPCAdapterError(
      "RPC_ENV_VAR_MISSING",
      `Missing environment variable(s) for RPC URL: ${[...missing].join(", ")}`,
      { operation: "resolveChain" },
    );
  }
  return resolved;
}

/**
 * Loads and validates a chain entry from the nearest compose.json.
 *
 * RPC URLs may contain `${NAME}` placeholders, which are resolved from the
 * process environment before the configuration is returned.
 */
export async function resolveChainConfig(options: ResolveChainOptions = {}): Promise<ResolvedChainConfig> {
  if (options.chainKey !== undefined && typeof options.chainKey !== "string") {
    throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", "chainKey must be a string", { operation: "resolveChain" });
  }

  const chainKey = options.chainKey === undefined ? "local" : options.chainKey;
  const startDir = options.projectRoot ?? process.cwd();
  const composePath = await findFileAncestor(startDir, "compose.json");
  if (!composePath) {
    throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", "compose.json not found", { operation: "resolveChain" });
  }

  let composeJson: unknown;
  try {
    composeJson = JSON.parse(await fs.readFile(composePath, "utf8"));
  } catch (error) {
    throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", `Unable to parse ${composePath}`, { operation: "resolveChain", cause: error });
  }

  const root = composeJson && typeof composeJson === "object" ? composeJson as Record<string, unknown> : undefined;
  const chains = root?.chains;
  if (!chains || typeof chains !== "object") {
    throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", "compose.json is missing a chains object", { operation: "resolveChain" });
  }

  const chain = (chains as Record<string, unknown>)[chainKey];
  if (!chain || typeof chain !== "object") {
    throw new RPCAdapterError("RPC_CHAIN_NOT_FOUND", `Chain '${chainKey}' was not found in compose.json`, { operation: "resolveChain" });
  }

  const entry = chain as Record<string, unknown>;
  if (typeof entry.rpc !== "string" || entry.rpc.trim() === "") {
    throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", `Chain '${chainKey}' has an invalid rpc value`, { operation: "resolveChain" });
  }
  if (!Number.isSafeInteger(entry.chainId) || (entry.chainId as number) <= 0) {
    throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", `Chain '${chainKey}' has an invalid chainId`, { operation: "resolveChain" });
  }

  const rpcUrl = interpolateRPCUrl(entry.rpc);
  if (!rpcUrl.trim()) {
    throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", `Chain '${chainKey}' resolved to an empty RPC URL`, { operation: "resolveChain" });
  }

  return { chainKey, rpcUrl, chainId: entry.chainId as number };
}
