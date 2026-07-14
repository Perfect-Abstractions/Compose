/**
 * Escapes special regex characters in a string so it can be safely
 * embedded in a `RegExp` pattern without altering the intended match.
 *
 * @param value - The user-provided string to escape.
 * @returns The escaped string safe for use in a RegExp.
 */
export function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
