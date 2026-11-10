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

/**
 * Returns the non-secret portion of an RPC endpoint for diagnostics.
 * Paths are omitted entirely because RPC providers commonly place API keys in
 * path segments; query strings, fragments, and userinfo are omitted as well.
 */
export function safeRpcEndpoint(rpcUrl: string): string | undefined {
  try {
    return new URL(rpcUrl).origin;
  } catch {
    return undefined;
  }
}

/**
 * Collects values from an endpoint that must not be echoed in a cause message.
 * Includes path segments too, since providers often use those as API keys.
 */
function endpointSecrets(rpcUrl?: string): string[] {
  if (!rpcUrl) return [];

  try {
    const url = new URL(rpcUrl);
    const values = [
      url.username,
      url.password,
      ...url.searchParams.values(),
      ...url.pathname.split("/"),
      url.hash.slice(1),
    ];
    return [...new Set(values.flatMap((value) => {
      if (!value) return [];
      try {
        return [value, decodeURIComponent(value)];
      } catch {
        return [value];
      }
    }))].filter(Boolean).sort((left, right) => right.length - left.length);
  } catch {
    return [];
  }
}

/** Redacts endpoint secrets, then replaces any URL in text with its safe origin. */
export function sanitizeRpcCause(message: string, rpcUrl?: string): string {
  let sanitized = message;

  for (const secret of endpointSecrets(rpcUrl)) {
    const escaped = secret.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    // Long API tokens should be removed even when adjacent to other text. For
    // short path names, use token boundaries to avoid mangling ordinary words.
    const pattern = secret.length >= 8
      ? new RegExp(escaped, "g")
      : new RegExp(`(^|[^\\p{L}\\p{N}])${escaped}(?=$|[^\\p{L}\\p{N}])`, "gu");
    sanitized = sanitized.replace(pattern, secret.length >= 8 ? "[REDACTED]" : "$1[REDACTED]");
  }

  return sanitized.replace(/https?:\/\/[^\s"'<>]+/gi, (candidate) => {
    let urlText = candidate;
    let punctuation = "";
    while (/[),.;!?]$/.test(urlText)) {
      punctuation = urlText.slice(-1) + punctuation;
      urlText = urlText.slice(0, -1);
    }
    return `${safeRpcEndpoint(urlText) ?? "[redacted URL]"}${punctuation}`;
  });
}
