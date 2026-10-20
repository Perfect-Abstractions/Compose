/**
 * Normalizes parsed `--` passthrough arguments.
 *
 * Commander exposes the tail after `--` as `unknown`; only string entries can
 * be forwarded to a framework command.
 *
 * @param value - The raw passthrough value from the parsed CLI flags.
 * @returns The string arguments in their original order.
 */
export function toPassthroughArgs(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}
