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
  }
}
