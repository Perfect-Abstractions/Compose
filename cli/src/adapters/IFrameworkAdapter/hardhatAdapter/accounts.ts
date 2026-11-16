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
