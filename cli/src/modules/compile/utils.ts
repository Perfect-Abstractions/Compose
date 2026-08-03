import fs from "node:fs";
import path from "node:path";

export function getNewestSourceMtime(sourceDir: string): number | null {
  if (!fs.existsSync(sourceDir)) return null;

  let newest = 0;
  const entries = fs.readdirSync(sourceDir, { recursive: true });

  for (const entry of entries) {
    const fullPath = path.join(sourceDir, String(entry));
    if (!fullPath.endsWith(".sol")) continue;

    try {
      const stat = fs.statSync(fullPath);
      if (stat.isFile() && stat.mtimeMs > newest) {
        newest = stat.mtimeMs;
      }
    } catch {
      // skip inaccessible files
    }
  }

  return newest > 0 ? newest : null;
}

export function getOldestArtifactMtime(artifactDir: string): number | null {
  if (!fs.existsSync(artifactDir)) return null;

  let oldest = Infinity;
  const entries = fs.readdirSync(artifactDir, { recursive: true });

  for (const entry of entries) {
    const fullPath = path.join(artifactDir, String(entry));
    try {
      const stat = fs.statSync(fullPath);
      if (stat.isFile() && stat.mtimeMs < oldest) {
        oldest = stat.mtimeMs;
      }
    } catch {
      // skip inaccessible files
    }
  }

  return oldest < Infinity ? oldest : null;
}
