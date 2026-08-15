import { statusCode } from "./utils";

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
 * Converts an unknown transport failure into a stable adapter error.
 * @param operation RPC operation that failed.
 * @param chainId Chain on which the operation was attempted.
 * @param error Original transport or client failure.
 * @returns A normalized adapter error with a stable error code.
 */
export function requestError(operation: string, chainId: number, error: unknown): RPCAdapterError {
  const status = statusCode(error);
  const code = status === 401 ? "RPC_UNAUTHORIZED" : "RPC_REQUEST_FAILED";
  return new RPCAdapterError(code, `RPC ${operation} failed on chain ${chainId}`, { operation, chainId, cause: error });
}
