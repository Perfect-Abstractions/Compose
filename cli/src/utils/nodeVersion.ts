/** Node.js release required by Hardhat 3 project initialization. */
export const HARDHAT_MINIMUM_NODE_VERSION = "22.13.0";

type ParsedVersion = {
  major: number;
  minor: number;
  patch: number;
};

/** Parses the leading `major.minor.patch` portion of a Node.js version. */
function parseVersion(version: string): ParsedVersion | null {
  const match = version.trim().match(/^v?(\d+)\.(\d+)\.(\d+)/);
  if (!match) return null;

  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3]),
  };
}

/**
 * Checks whether a Node.js version is at least the given minimum version.
 *
 * @param version - Version to check, such as `process.versions.node`.
 * @param minimum - Minimum version in `major.minor.patch` form.
 * @returns True when the version meets or exceeds the minimum.
 */
export function isNodeVersionAtLeast(version: string, minimum: string): boolean {
  const current = parseVersion(version);
  const required = parseVersion(minimum);
  if (!current || !required) return false;

  if (current.major !== required.major) return current.major > required.major;
  if (current.minor !== required.minor) return current.minor > required.minor;
  return current.patch >= required.patch;
}

/**
 * Throws when the running Node.js version cannot initialize a Hardhat 3 project.
 *
 * The CLI requires Node.js 22+, but Hardhat 3's official initializer requires
 * Node.js 22.13+. The check runs before scaffolding so users get an actionable
 * error instead of a failure from Hardhat's template command.
 *
 * @param version - Node.js version to check, defaulting to the current runtime.
 * @throws {Error} If the version is older than Hardhat's minimum requirement.
 */
export function assertHardhatNodeVersion(version: string = process.versions.node): void {
  if (!isNodeVersionAtLeast(version, HARDHAT_MINIMUM_NODE_VERSION)) {
    throw new Error(
      `Hardhat 3 requires Node.js ${HARDHAT_MINIMUM_NODE_VERSION} or newer; current version is ${version}. `
      + "Upgrade Node.js before scaffolding a Hardhat project.",
    );
  }
}
