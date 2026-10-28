import fs from "node:fs/promises";
import path from "node:path";

/** Converts a Hardhat compiler source name into its readable filesystem path. */
export function resolveHardhatAstSourcePath(projectRoot: string, sourceName: string): string {
  const segments = sourceName.replace(/\\/g, "/").split("/");

  if (segments[0] === "project") {
    return path.resolve(projectRoot, ...segments.slice(1));
  }

  if (segments[0] === "npm") {
    const packageNameIndex = segments[1]?.startsWith("@") ? 2 : 1;
    const versionedPackageName = segments[packageNameIndex] ?? "";
    const versionSeparator = versionedPackageName.lastIndexOf("@");
    if (versionSeparator > 0) {
      segments[packageNameIndex] = versionedPackageName.slice(0, versionSeparator);
    }
    return path.resolve(projectRoot, "node_modules", ...segments.slice(1));
  }

  return path.isAbsolute(sourceName)
    ? path.normalize(sourceName)
    : path.resolve(projectRoot, sourceName);
}

/**
 * Resolves the Hardhat artifact source name for a file on disk.
 *
 * Project files map to their project-relative path; files under
 * `node_modules` map to `npm/<package>@<version>/<subpath>`, mirroring the
 * source names Hardhat writes into its artifacts directory. Returns null
 * when the file cannot be attributed to a Hardhat source name.
 */
export async function resolveHardhatArtifactSourceName(
  projectRoot: string,
  sourcePath: string,
): Promise<string | null> {
  const normalized = path.resolve(sourcePath);

  const nodeModulesRoot = path.join(projectRoot, "node_modules");
  const packageRelative = path.relative(nodeModulesRoot, normalized);
  if (packageRelative && !packageRelative.startsWith("..") && !path.isAbsolute(packageRelative)) {
    const segments = packageRelative.replace(/\\/g, "/").split("/");
    const packageName = segments[0].startsWith("@") ? segments.slice(0, 2).join("/") : segments[0];
    const subpath = segments.slice(packageName.split("/").length).join("/");
    if (!subpath) return null;

    try {
      const packageJson = JSON.parse(
        await fs.readFile(path.join(nodeModulesRoot, packageName, "package.json"), "utf8"),
      ) as { version?: unknown };
      const version = typeof packageJson.version === "string" ? packageJson.version : "";
      if (!version) return null;
      return `npm/${packageName}@${version}/${subpath}`;
    } catch {
      return null;
    }
  }

  const projectRelative = path.relative(projectRoot, normalized);
  if (projectRelative && !projectRelative.startsWith("..") && !path.isAbsolute(projectRelative)) {
    return projectRelative.replace(/\\/g, "/");
  }

  return null;
}
