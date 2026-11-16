import { readFileSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import type { DeployToolbox } from "../types";

/**
 * Detects the Hardhat ethers or viem toolbox from package.json.
 *
 * @param projectRoot - Absolute project root.
 * @returns The detected toolbox variant.
 * @throws {Error} If the project has no supported Hardhat toolbox.
 */
export async function detectHardhatToolbox(projectRoot: string): Promise<DeployToolbox> {
  let packageJson: {
    dependencies?: Record<string, string>;
    devDependencies?: Record<string, string>;
  };
  try {
    packageJson = JSON.parse(
      await fs.readFile(path.join(projectRoot, "package.json"), "utf8"),
    ) as {
      dependencies?: Record<string, string>;
      devDependencies?: Record<string, string>;
    };
  } catch {
    throw new Error("Cannot determine the Hardhat toolbox: package.json is missing or invalid.");
  }

  const dependencies = { ...packageJson.dependencies, ...packageJson.devDependencies };
  if (
    dependencies["@nomicfoundation/hardhat-toolbox-viem"]
    || dependencies["@nomicfoundation/hardhat-viem"]
  ) {
    return "viem";
  }
  if (
    dependencies["@nomicfoundation/hardhat-toolbox-mocha-ethers"]
    || dependencies["@nomicfoundation/hardhat-ethers"]
  ) {
    return "ethers";
  }

  throw new Error(
    "Compose requires @nomicfoundation/hardhat-ethers or @nomicfoundation/hardhat-viem. "
    + "Install the toolbox matching your Hardhat project, then retry.",
  );
}

/** Ensures that a detected Hardhat project uses the supported Hardhat 3 API. */
export function assertHardhat3(projectRoot: string): void {
  const packagePath = path.join(projectRoot, "package.json");
  let packageJson: {
    dependencies?: Record<string, string>;
    devDependencies?: Record<string, string>;
  };
  try {
    packageJson = JSON.parse(readFileSync(packagePath, "utf8")) as {
      dependencies?: Record<string, string>;
      devDependencies?: Record<string, string>;
    };
  } catch {
    throw new Error("Hardhat project package.json is missing or invalid; Compose supports Hardhat 3 projects only.");
  }

  let version: string | undefined;
  try {
    const installedPath = path.join(projectRoot, "node_modules", "hardhat", "package.json");
    version = (JSON.parse(readFileSync(installedPath, "utf8")) as { version?: string }).version;
  } catch {
    version = packageJson.devDependencies?.hardhat ?? packageJson.dependencies?.hardhat;
  }

  const match = version?.match(/(?:^|[^0-9])(\d+)\.(\d+)(?:\.(\d+))?/);
  if (!version || !match) {
    throw new Error("Could not determine the Hardhat version. Install Hardhat 3 in this project before running Compose.");
  }

  const major = Number(match[1]);
  const minor = Number(match[2]);
  if (major !== 3 || minor < 8) {
    throw new Error(
      `Compose supports Hardhat 3.8 or newer; this project declares or installs '${version}'.`,
    );
  }
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
