import { withRetry } from "viem";
import { errorChain, errorText, statusCode } from "./utils";

/** Maximum number of retries after the initial RPC request. */
const RETRY_COUNT = 2;
/** Fallback delays, in milliseconds, for successive retries. */
const RETRY_DELAYS = [100, 200] as const;
/** Maximum delay accepted from a server Retry-After header. */
const RETRY_AFTER_CAP = 2_000;

/**
 * Reads a Retry-After header and converts it to a bounded delay.
 * @param error Error that may contain response headers.
 * @returns Retry delay in milliseconds, or `undefined` when absent or invalid.
 */
function retryAfterMs(error: unknown): number | undefined {
  for (const item of errorChain(error)) {
    if (!item || typeof item !== "object") continue;
    const headers = (item as { headers?: Headers; response?: { headers?: Headers } }).headers
      ?? (item as { response?: { headers?: Headers } }).response?.headers;
    const value = headers?.get("retry-after");
    if (!value) continue;

    const seconds = Number(value);
    if (Number.isFinite(seconds)) return Math.min(Math.max(seconds * 1_000, 0), RETRY_AFTER_CAP);

    const timestamp = Date.parse(value);
    if (!Number.isNaN(timestamp)) return Math.min(Math.max(timestamp - Date.now(), 0), RETRY_AFTER_CAP);
  }
  return undefined;
}

/**
 * Identifies failures that are safe to retry without changing chain state.
 * @param error Error produced by the failed RPC request.
 * @returns `true` when the failure is considered transient.
 */
function isTransientError(error: unknown): boolean {
  const status = statusCode(error);
  if (status === 401) return false;
  if (status === 429 || status === 502 || status === 503) return true;

  for (const item of errorChain(error)) {
    if (!item || typeof item !== "object") continue;
    const code = (item as { code?: unknown }).code;
    if (code === 429 || code === "ECONNRESET" || code === "ETIMEDOUT") return true;
  }

  const text = errorText(error);
  return [
    "econnreset",
    "connection reset",
    "fetch failed",
    "network error",
    "etimedout",
    "econnrefused",
    "socket hang up",
  ].some((term) => text.includes(term));
}

/**
 * Selects the server-provided delay or the adapter's backoff schedule.
 * @param input Retry attempt count and failure information.
 * @returns Delay before the next attempt, in milliseconds.
 */
function retryDelay({ count, error }: { count: number; error: Error }): number {
  return retryAfterMs(error) ?? RETRY_DELAYS[Math.min(count, RETRY_DELAYS.length - 1)] ?? RETRY_DELAYS.at(-1)!;
}

/**
 * Executes an RPC request with bounded retries for transient failures only.
 * @param request Asynchronous RPC operation to execute.
 * @returns The successful request result.
 * @throws The final request error when retries are exhausted or the failure is permanent.
 */
export async function retryRPC<T>(request: () => Promise<T>): Promise<T> {
  return withRetry(request, {
    retryCount: RETRY_COUNT,
    delay: retryDelay,
    shouldRetry: ({ error }) => isTransientError(error),
  });
}
