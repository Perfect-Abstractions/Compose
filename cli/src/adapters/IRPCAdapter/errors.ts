import { errorChain, safeRpcEndpoint, sanitizeRpcCause, statusCode } from "./utils";

/** Stable error categories emitted by the RPC adapter. */
export type RPCErrorCode =
  | "RPC_INVALID_CONFIGURATION"
  | "RPC_ENV_VAR_MISSING"
  | "RPC_CHAIN_NOT_FOUND"
  | "RPC_CHAIN_ID_MISMATCH"
  | "RPC_UNAUTHORIZED"
  | "RPC_CONTRACT_NOT_FOUND"
  | "RPC_REQUEST_FAILED"
  | "RPC_INVALID_ADDRESS";

/**
 * Diagnostic error thrown at the RPC/configuration boundary.
 *
 * The stable code is intended for programmatic handling; operation and chain
 * ID provide context, while the original failure remains available as cause.
 * @param code Stable adapter error category.
 * @param message Human-readable diagnostic message.
 * @param options Operation context and optional chain ID or original cause.
 */
export class RPCAdapterError extends Error {
  /** Stable category used by callers and CLI error handling. */
  readonly code: RPCErrorCode;
  /** RPC or configuration operation that produced the error. */
  readonly operation: string;
  /** Chain involved in the operation, when one was resolved. */
  readonly chainId?: number;

  constructor(
    code: RPCErrorCode,
    message: string,
    options: { operation: string; chainId?: number; cause?: unknown },
  ) {
    super(message, { cause: options.cause });
    this.name = "RPCAdapterError";
    this.code = code;
    this.operation = options.operation;
    this.chainId = options.chainId;
  }
}

/**
 * Returns the deepest non-empty message in an error's cause chain.
 *
 * Transport failures hide the useful reason (e.g. `connect ECONNREFUSED`) in a
 * cause, so the summary walks to the bottom instead of quoting the wrapper.
 * @param error Error whose cause chain should be summarized.
 * @returns The collapsed, bounded message, or `undefined` when none is found.
 */
function causeSummary(error: unknown): string | undefined {
  const causes = errorChain(error).slice(1);
  for (let index = causes.length - 1; index >= 0; index -= 1) {
    const item = causes[index];
    const raw = item instanceof Error ? item.message : typeof item === "string" ? item : "";
    const message = raw.replace(/\s+/g, " ").trim();
    if (message) return message.length > 200 ? `${message.slice(0, 197)}...` : message;
  }
  return undefined;
}

/**
 * Converts an unknown transport failure into a stable adapter error.
 * @param operation RPC operation that failed.
 * @param chainId Chain on which the operation was attempted.
 * @param error Original transport or client failure.
 * @param rpcUrl Endpoint the operation targeted, when known.
 * @returns A normalized adapter error with a stable error code.
 */
export function requestError(
  operation: string,
  chainId: number,
  error: unknown,
  rpcUrl?: string,
): RPCAdapterError {
  const status = statusCode(error);
  const code = status === 401 ? "RPC_UNAUTHORIZED" : "RPC_REQUEST_FAILED";
  const endpoint = rpcUrl ? safeRpcEndpoint(rpcUrl) : undefined;
  const target = endpoint ? ` at ${endpoint}` : "";
  const rawCause = causeSummary(error);
  const cause = rawCause ? sanitizeRpcCause(rawCause, rpcUrl) : undefined;
  const detail = cause ? `: ${cause}` : "";
  return new RPCAdapterError(code, `RPC ${operation} failed on chain ${chainId}${target}${detail}`, {
    operation,
    chainId,
    cause: error,
  });
}
