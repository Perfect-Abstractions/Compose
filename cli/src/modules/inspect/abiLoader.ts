import fs from "node:fs/promises";
import path from "node:path";
import { keccak256, slice, toBytes } from "viem";
import { FrameworkModule, type Framework } from "../../modules/framework/module";
import type { AbiEntry } from "./types";

/**
 * Extracts human-readable function signatures from a parsed ABI array.
 *
 * Only `function` entries with a `name` are included; fallback and receive
 * entries are skipped.
 *
 * @param abi - The parsed ABI entries.
 * @returns An array of signatures like `"transfer(address,uint256)"`.
 */
function extractSignaturesFromAbi(abi: AbiEntry[]): string[] {
  const signatures: string[] = [];
  for (const entry of abi) {
    if (entry.type !== "function" || !entry.name) continue;
    const params = entry.inputs?.map((i) => i.type).join(",") ?? "";
    signatures.push(`${entry.name}(${params})`);
  }
  return signatures;
}

/**
 * Computes the 4-byte selector for a function signature using Keccak-256.
 *
 * @param signature - The function signature (e.g., `"transfer(address,uint256)"`).
 * @returns The lowercase hex-encoded 4-byte selector.
 */
function computeSelector(signature: string): string {
  const hash = keccak256(toBytes(signature));
  return slice(hash, 0, 4).toLowerCase();
}

/**
 * Reads all compiled ABI JSON files from the given directory.
 *
 * Expects Hardhat-style (`artifacts/`) or Foundry-style (`out/`) artifact
 * layouts where each JSON file contains an `abi` array.
 *
 * @param dir - Absolute path to the artifacts directory.
 * @returns An array of parsed ABI arrays, one per artifact file.
 */
async function readAbiFiles(dir: string): Promise<AbiEntry[][]> {
  const abis: AbiEntry[][] = [];
  let entries: string[];
  try {
    entries = await fs.readdir(dir, { recursive: true });
  } catch {
    return abis;
  }
  for (const entry of entries) {
    if (!entry.endsWith(".json")) continue;
    const fullPath = path.join(dir, entry);
    try {
      const content = await fs.readFile(fullPath, "utf8");
      const parsed = JSON.parse(content);
      if (Array.isArray(parsed?.abi)) {
        abis.push(parsed.abi);
      }
    } catch {
      // skip unparseable files
    }
  }
  return abis;
}

/**
 * Loads all function signatures from the project's compiled ABI files and
 * returns a selector-to-signature map.
 *
 * Automatically detects the framework (Hardhat or Foundry) to locate the
 * correct artifact directory.
 *
 * @param projectRoot - Absolute path to the project root.
 * @param framework - Optional framework override. When `null` or omitted the
 *     framework is auto-detected.
 * @returns A map from lowercase 4-byte selectors to function signatures.
 */
export async function loadProjectSignatures(
  projectRoot: string,
  framework?: Framework | null,
): Promise<Map<string, string>> {
  const fw = framework ?? FrameworkModule.detect(projectRoot);
  const artifactDir = fw === "hardhat"
    ? path.join(projectRoot, "artifacts")
    : path.join(projectRoot, "out");

  const abis = await readAbiFiles(artifactDir);
  const map = new Map<string, string>();
  for (const abi of abis) {
    for (const sig of extractSignaturesFromAbi(abi)) {
      const selector = computeSelector(sig);
      if (!map.has(selector)) {
        map.set(selector, sig);
      }
    }
  }
  return map;
}
