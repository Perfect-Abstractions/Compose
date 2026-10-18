import path from "node:path";
import fs from "node:fs/promises";
import { listJsonFiles } from "../../../utils/solidityAst";

/** Resolve an artifact by its compiler source identity, including npm source aliases. */
export async function resolveDeploymentContractReference(projectRoot: string, artifactsRoot: string, sourcePath: string, contractName: string): Promise<string> {
  const normalize = (value: string): string => process.platform === "win32" ? path.resolve(value).toLowerCase() : path.resolve(value);
  const matches = new Set<string>();
  for (const file of await listJsonFiles(artifactsRoot)) {
    if (path.basename(file) !== `${contractName}.json`) continue;
    const artifact = JSON.parse(await fs.readFile(file, "utf8")) as { sourceName?: string; inputSourceName?: string; contractName?: string };
    if (artifact.contractName !== contractName || !artifact.sourceName) continue;
    const compilerSource = artifact.inputSourceName ?? artifact.sourceName;
    if (normalize(resolveHardhatAstSourcePath(projectRoot, compilerSource)) === normalize(sourcePath)) {
      matches.add(`${artifact.sourceName}:${contractName}`);
    }
  }
  if (matches.size !== 1) throw new Error(`Deployment artifact not found or ambiguous: ${sourcePath}:${contractName}`);
  return [...matches][0];
}

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
