import fs from "node:fs";
import path from "node:path";

export type Framework = "foundry" | "hardhat";

const HARDHAT_CONFIG_FILES = [
  "hardhat.config.js",
  "hardhat.config.ts",
  "hardhat.config.cjs",
  "hardhat.config.mjs",
];

export const FrameworkModule = {
  detect(projectRoot: string): Framework | null {
    if (fs.existsSync(path.join(projectRoot, "foundry.toml"))) {
      return "foundry";
    }

    if (HARDHAT_CONFIG_FILES.some((f) => fs.existsSync(path.join(projectRoot, f)))) {
      return "hardhat";
    }

    return null;
  },

  /** Ensures that a detected Hardhat project uses the supported Hardhat 3 API. */
  assertHardhat3(projectRoot: string): void {
    const packagePath = path.join(projectRoot, "package.json");
    let packageJson: {
      dependencies?: Record<string, string>;
      devDependencies?: Record<string, string>;
    };
    try {
      packageJson = JSON.parse(fs.readFileSync(packagePath, "utf8")) as {
        dependencies?: Record<string, string>;
        devDependencies?: Record<string, string>;
      };
    } catch {
      throw new Error("Hardhat project package.json is missing or invalid; Compose supports Hardhat 3 projects only.");
    }

    let version: string | undefined;
    try {
      const installedPath = path.join(projectRoot, "node_modules", "hardhat", "package.json");
      version = (JSON.parse(fs.readFileSync(installedPath, "utf8")) as { version?: string }).version;
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
}
