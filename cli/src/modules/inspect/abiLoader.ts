import fs from "node:fs/promises";
import path from "node:path";
import { keccak256, slice, toBytes } from "viem";
import { FrameworkModule, type Framework } from "../../modules/framework/module";

type AbiEntry = {
  type: string;
  name?: string;
  inputs?: { type: string }[];
};

function extractSignaturesFromAbi(abi: AbiEntry[]): string[] {
  const signatures: string[] = [];
  for (const entry of abi) {
    if (entry.type !== "function" || !entry.name) continue;
    const params = entry.inputs?.map((i) => i.type).join(",") ?? "";
    signatures.push(`${entry.name}(${params})`);
  }
  return signatures;
}

function computeSelector(signature: string): string {
  const hash = keccak256(toBytes(signature));
  return slice(hash, 0, 4).toLowerCase();
}

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
