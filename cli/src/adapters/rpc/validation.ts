import { RPCAdapterError } from "./errors";
import type { RPCAdapterOptions } from "./types";

/**
 * Validates an RPC endpoint and expected chain before client construction.
 * @param options RPC endpoint and expected chain configuration.
 * @returns Nothing when the configuration is valid.
 * @throws {RPCAdapterError} If the URL or chain ID is invalid.
 */
export function validateOptions({ rpcUrl, chainId }: RPCAdapterOptions): void {
  if (!rpcUrl) throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", "RPC URL is required", { operation: "create" });
  try {
    const url = new URL(rpcUrl);
    if (url.protocol !== "http:" && url.protocol !== "https:") throw new Error("RPC URL must use HTTP or HTTPS");
  } catch (error) {
    throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", "RPC URL must be a valid HTTP or HTTPS URL", { operation: "create", cause: error });
  }
  if (!Number.isSafeInteger(chainId) || chainId <= 0) {
    throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", "chainId must be a positive integer", { operation: "create", cause: chainId });
  }
}
