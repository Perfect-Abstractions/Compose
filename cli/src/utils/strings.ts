/**
 * Converts a PascalCase or snake_case string to camelCase.
 *
 * @param value - The string to convert.
 * @returns The camelCase version of the input, or an empty string if the result is empty.
 */
export function toCamelCase(value: string): string {
  const words = value.match(/[A-Z]?[a-z0-9]+|[A-Z]+(?![a-z])/g) ?? [value];
  return words
    .map((word) => word.toLowerCase())
    .map((word, index) =>
      index === 0 ? word : `${word.charAt(0).toUpperCase()}${word.slice(1)}`,
    )
    .join("");
}

/**
 * Deduplicates an array of strings, preserving first occurrence order.
 *
 * @param names - Array of strings that may contain duplicates.
 * @returns A new array with only unique strings.
 */
export function uniqueStrings(names: string[]): string[] {
  return [...new Set(names)];
}

/**
 * Splits a comma-separated string into an array of trimmed, non-empty strings.
 *
 * @param value - The comma-separated string (or unknown value).
 * @returns Array of trimmed, non-empty strings.
 */
export function splitCommaSeparated(value: unknown): string[] {
  if (!value) return [];
  return String(value)
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}
