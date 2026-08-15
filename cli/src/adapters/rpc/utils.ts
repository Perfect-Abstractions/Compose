/**
 * Returns an error and each distinct cause in its cause chain.
 * @param error Error whose causes should be traversed.
 * @returns The error and its reachable cause values in traversal order.
 */
export function errorChain(error: unknown): unknown[] {
  const errors: unknown[] = [];
  let current = error;
  while (current && typeof current === "object" && !errors.includes(current)) {
    errors.push(current);
    current = "cause" in current ? (current as { cause?: unknown }).cause : undefined;
  }
  return errors;
}

/**
 * Combines error messages across an error's cause chain for matching.
 * @param error Error whose messages should be combined.
 * @returns Lowercase text containing all chained error messages.
 */
export function errorText(error: unknown): string {
  return errorChain(error)
    .map((item) => (item instanceof Error ? item.message : String(item)))
    .join(" ")
    .toLowerCase();
}

/**
 * Finds an HTTP/status code in an error or one of its causes.
 * @param error Error that may contain a status code.
 * @returns The first numeric status code found, or `undefined`.
 */
export function statusCode(error: unknown): number | undefined {
  for (const item of errorChain(error)) {
    if (!item || typeof item !== "object") continue;
    const value = item as { status?: unknown; statusCode?: unknown; response?: { status?: unknown } };
    const status = value.status ?? value.statusCode ?? value.response?.status;
    if (typeof status === "number") return status;
  }
  return undefined;
}
