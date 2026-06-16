// Escape user-provided text so it can be safely embedded in a RegExp.
export function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
