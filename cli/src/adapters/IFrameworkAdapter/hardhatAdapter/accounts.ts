import fs from "node:fs/promises";
import path from "node:path";
import { getAddress } from "viem";
import type { SignerAddressOptions } from "../types";
import { runCommandCaptureStdout } from "../../../utils/exec";
import { atomicWriteFile, toProjectRelativePath } from "../../../utils/files";
import { loadTemplate } from "../../../utils/codegen";
import {
  composeRuntimeDir,
  ensureComposeRuntimeDir,
} from "../../../utils/composeRuntime";
import { assertHardhat3, detectHardhatToolbox } from "./helpers";

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Conservatively extracts a simple object-property block from the generated
 * Hardhat config shape. Unsupported config syntax returns null rather than
 * guessing which key variable a network uses.
 */
function extractPropertyBlocks(source: string, propertyName: string): Array<string | null> {
  const escapedName = escapeRegExp(propertyName);
  const propertyPattern = new RegExp(
    `^[\\t ]*(?:${escapedName}|["']${escapedName}["'])\\s*:\\s*\\{`,
    "gm",
  );
  const matches = [...source.matchAll(propertyPattern)];
  return matches.map((propertyMatch) => {
    if (propertyMatch.index === undefined) return null;
    const openBrace = source.indexOf("{", propertyMatch.index);
    const closeBrace = findMatchingBrace(source, openBrace);
    return closeBrace === null ? null : source.slice(openBrace + 1, closeBrace);
  });
}

function findMatchingBrace(source: string, openBrace: number): number | null {
  let depth = 0;
  let quote: "'" | "\"" | "`" | null = null;
  let lineComment = false;
  let blockComment = false;
  let escaped = false;

  for (let index = openBrace; index < source.length; index += 1) {
    const character = source[index] ?? "";
    const next = source[index + 1] ?? "";

    if (lineComment) {
      if (character === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      if (character === "*" && next === "/") {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote) {
      if (escaped) {
        escaped = false;
      } else if (character === "\\") {
        escaped = true;
      } else if (character === quote) {
        quote = null;
      }
      continue;
    }

    if (character === "/" && next === "/") {
      lineComment = true;
      index += 1;
      continue;
    }
    if (character === "/" && next === "*") {
      blockComment = true;
      index += 1;
      continue;
    }
    // A regex literal or division expression is outside the simple generated
    // config shape this helper supports; avoid returning a guessed block.
    if (character === "/") return null;
    if (character === "'" || character === "\"" || character === "`") {
      quote = character;
      continue;
    }
    if (character === "{") depth += 1;
    if (character === "}") {
      depth -= 1;
      if (depth === 0) return index;
    }
  }

  return null;
}

/**
 * Reads the selected network's one literal `configVariable` signer reference.
 * Returns null for custom or ambiguous Hardhat config so account setup can
 * display safe generic guidance instead of suggesting the wrong key name.
 */
export async function readHardhatAccountKeyVariable(
  projectRoot: string,
  chainKey: string,
): Promise<string | null> {
  let config: string;
  try {
    config = await fs.readFile(path.join(projectRoot, "hardhat.config.ts"), "utf8");
  } catch {
    return null;
  }

  const networksBlocks = extractPropertyBlocks(config, "networks");
  if (networksBlocks.length === 0 || networksBlocks.some((block) => block === null)) return null;

  let selectedNetworkFound = false;
  let selectedVariable: string | null = null;
  for (const networks of networksBlocks) {
    const networkBlocks = extractPropertyBlocks(networks ?? "", chainKey);
    if (networkBlocks.length === 0) continue;
    if (networkBlocks.length !== 1 || networkBlocks[0] === null) return null;

    selectedNetworkFound = true;
    const accountMatches = [...networkBlocks[0].matchAll(/^[\t ]*accounts\s*:\s*\[([^\]]*)\]/gm)];
    if (accountMatches.length !== 1) {
      selectedVariable = null;
      continue;
    }

    const accountExpression = accountMatches[0]?.[1]?.trim() ?? "";
    const variable = accountExpression.match(
      /^configVariable\s*\(\s*(["'])([A-Za-z_][A-Za-z0-9_]*)\1\s*\)$/,
    );
    selectedVariable = variable?.[2] ?? null;
  }

  return selectedNetworkFound ? selectedVariable : null;
}

/** Lists the signer addresses a Hardhat project configures for the target chain. */
export async function listHardhatSignerAddresses(
  options: SignerAddressOptions,
): Promise<string[]> {
  const { projectRoot, chainKey, rpcUrl, chainId } = options;
  assertHardhat3(projectRoot);
  const toolbox = await detectHardhatToolbox(projectRoot);
  const probePath = path.join(composeRuntimeDir(projectRoot, "hardhat"), "account-probe.ts");
  const accountRead = toolbox === "viem"
    ? 'const addresses = (await connection.viem.getWalletClients()).map((wallet) => wallet.account.address);'
    : 'const addresses = await Promise.all((await connection.ethers.getSigners()).map((signer) => signer.getAddress()));';
  const template = await loadTemplate("deploy", "compose-hardhat-account-probe.ts");
  const script = template
    .split("{{CHAIN_KEY}}").join(JSON.stringify(chainKey))
    .split("{{CHAIN_ID}}").join(String(chainId))
    .split("{{ACCOUNT_READ}}").join(accountRead);

  await ensureComposeRuntimeDir(projectRoot, "hardhat");
  await atomicWriteFile(probePath, script);

  // The probe only reads network configuration; it must not trigger a build.
  // Deploy builds once under the production profile and relies on those
  // artifacts, and listing signers must work before the project is built.
  // The profile flag must match the deploy command because config-override
  // profiles can change network accounts, which would otherwise resolve a
  // different signer here than the broadcast actually uses.
  // The marker is consumed programmatically; do not echo the full signer list.
  const output = await runCommandCaptureStdout(
    "npx",
    ["hardhat", "--build-profile", "production", "run", "--no-compile", toProjectRelativePath(projectRoot, probePath), "--network", chainKey],
    {
      cwd: projectRoot,
      env: { COMPOSE_DEPLOY_RPC_URL: rpcUrl },
      forwardStdout: false,
    },
  );
  const marker = output.split(/\r?\n/).find((line) => line.startsWith("COMPOSE_ACCOUNT_ADDRESSES:"));
  if (!marker) throw new Error("Hardhat did not report its configured signer addresses.");
  const parsed = JSON.parse(marker.slice("COMPOSE_ACCOUNT_ADDRESSES:".length)) as unknown;
  if (!Array.isArray(parsed) || !parsed.every((address) => typeof address === "string")) {
    throw new Error("Hardhat returned an invalid signer address list.");
  }
  return parsed.map((address) => getAddress(address));
}
