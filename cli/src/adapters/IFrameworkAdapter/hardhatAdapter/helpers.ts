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
