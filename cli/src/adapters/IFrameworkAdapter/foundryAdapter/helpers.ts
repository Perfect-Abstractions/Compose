/** Adds missing settings to a TOML section without overwriting existing values. */
export function ensureTomlSectionSettings(
  content: string,
  section: string,
  settings: Record<string, string>,
): string {
  const lines = content.replace(/\r\n/g, "\n").split("\n");
  if (lines.at(-1) === "") lines.pop();

  let sectionIndex = lines.findIndex((line) => line.trim() === `[${section}]`);
  if (sectionIndex === -1) {
    if (lines.length > 0 && lines.at(-1)?.trim() !== "") lines.push("");
    sectionIndex = lines.length;
    lines.push(`[${section}]`);
  }

  let sectionEnd = lines.findIndex(
    (line, index) => index > sectionIndex && /^\s*\[[^\]]+\]\s*$/.test(line),
  );
  if (sectionEnd === -1) sectionEnd = lines.length;

  const sectionLines = lines.slice(sectionIndex + 1, sectionEnd);
  const missingSettings = Object.entries(settings)
    .filter(([key]) => !sectionLines.some((line) => new RegExp(`^\\s*${key}\\s*=`).test(line)))
    .map(([key, value]) => `${key} = ${value}`);

  lines.splice(sectionEnd, 0, ...missingSettings);
  return `${lines.join("\n")}\n`;
}
