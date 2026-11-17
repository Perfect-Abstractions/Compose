/**
 * Ensures a `.gitignore` entry exists without touching existing content.
 *
 * @param content - Current `.gitignore` content (may be empty).
 * @param entry - Entry to add when it is not already listed.
 * @returns The content unchanged, or with the entry appended on its own line.
 */
export function ensureGitignoreEntry(content: string, entry: string): string {
  const lines = content.split(/\r?\n/).map((line) => line.trim());
  if (lines.includes(entry)) return content;

  const separator = content === "" || content.endsWith("\n") ? "" : "\n";
  return `${content}${separator}${entry}\n`;
}

/**
 * Ensures several `.gitignore` entries exist, preserving their given order.
 *
 * @param content - Current `.gitignore` content (may be empty).
 * @param entries - Entries to add when they are not already listed.
 * @returns The content unchanged, or with the missing entries appended.
 */
export function ensureGitignoreEntries(content: string, entries: string[]): string {
  return entries.reduce((current, entry) => ensureGitignoreEntry(current, entry), content);
}
