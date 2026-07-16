import { FrameworkDependencies } from "./types";

/**
 * Returns the framework-specific dependencies needed for a Compose project.
 * Foundry uses git submodules; Hardhat uses npm packages.
 *
 * @param framework - The target framework ("foundry" or "hardhat").
 * @param toolbox - The Hardhat toolbox ("ethers" or "viem"). Ignored for Foundry.
 * @returns The dependency list and package type label.
 */
export function getFrameworkDependencies(
  framework: string,
  toolbox?: string,
): FrameworkDependencies {
  if (framework === "foundry") {
    return {
      deps: [
        { name: "forge-std", version: "(git submodule)" },
        { name: "Perfect-Abstractions/Compose", version: "(git submodule)" },
      ],
      packageType: "forge packages",
    };
  }

  const devDeps: Record<string, string> =
    toolbox === "viem"
      ? {
          hardhat: "^3.8.0",
          "@nomicfoundation/hardhat-toolbox-viem": "^5.0.0",
        }
      : {
          hardhat: "^3.8.0",
          "@nomicfoundation/hardhat-toolbox-mocha-ethers": "^3.0.0",
        };

  return {
    deps: [
      { name: "@perfect-abstractions/compose", version: "latest" },
      ...Object.entries(devDeps).map(([name, version]) => ({ name, version })),
    ],
    packageType: "npm packages",
  };
}
