import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { getAddress, isAddress, type Hex } from "viem";
import type {
  AccountAddressResolution,
  AccountResolutionOptions,
  DeploySignerOptions,
  SignerAddressOptions,
} from "../types";
import { runCommandCaptureStdout } from "../../../utils/exec";
import { FOUNDRY_SIGNING_PASSTHROUGH_OPTIONS } from "../../../utils/args";

const EMPTY_ACCOUNT: AccountAddressResolution = {
  address: null,
  exists: false,
  requiresUnlock: false,
};

function foundryKeystoreDirectory(): string {
  // `forge script --account` resolves names from Foundry's default keystore
  // directory. FOUNDRY_DIR controls tool installation, not this account path.
  return path.join(os.homedir(), ".foundry", "keystores");
}

async function foundryKeystorePath(accountName: string): Promise<string | null> {
  const directory = foundryKeystoreDirectory();
  for (const filename of [accountName, `${accountName}.json`]) {
    const filePath = path.join(directory, filename);
    try {
      await fs.access(filePath);
      return filePath;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }
  return null;
}

/** Reads a Foundry keystore's plaintext public address without unlocking it. */
export async function readFoundryAccount(accountName: string): Promise<AccountAddressResolution> {
  const filePath = await foundryKeystorePath(accountName);
  if (!filePath) return EMPTY_ACCOUNT;

  let keystore: { address?: unknown };
  try {
    keystore = JSON.parse(await fs.readFile(filePath, "utf8")) as { address?: unknown };
  } catch (error) {
    throw new Error(
      `Unable to read Foundry keystore at ${filePath}: ${(error as Error).message}`,
      { cause: error },
    );
  }

  if (typeof keystore.address !== "string") {
    return { address: null, exists: true, requiresUnlock: true };
  }

  const address = keystore.address.startsWith("0x") ? keystore.address : `0x${keystore.address}`;
  if (!isAddress(address, { strict: false })) {
    return { address: null, exists: true, requiresUnlock: true };
  }

  return { address: getAddress(address), exists: true, requiresUnlock: false };
}

/** Resolves a Foundry account address, unlocking the keystore when permitted. */
export async function resolveFoundryAccount(
  accountName: string,
  projectRoot: string,
  options: AccountResolutionOptions = {},
): Promise<AccountAddressResolution> {
  const stored = await readFoundryAccount(accountName);
  if (stored.address || !stored.exists || !options.allowUnlock) return stored;

  options.onUnlock?.();
  const output = await runCommandCaptureStdout(
    "cast",
    ["wallet", "address", "--account", accountName],
    { cwd: projectRoot, forwardStdout: false },
  );
  const address = output.match(/\b0x[0-9a-fA-F]{40}\b/)?.[0];
  if (!address || !isAddress(address, { strict: false })) {
    throw new Error(`Foundry did not return a public address for keystore account '${accountName}'.`);
  }

  return { address: getAddress(address), exists: true, requiresUnlock: false };
}

/** Reads the first value for one of `names` from Foundry passthrough arguments. */
function readOption(args: string[], names: string[]): string | undefined {
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    for (const name of names) {
      if (argument === name) {
        const value = args[index + 1];
        return value && !value.startsWith("-") ? value : undefined;
      }
      if (argument.startsWith(`${name}=`)) {
        const value = argument.slice(name.length + 1);
        return value || undefined;
      }
    }
  }
  return undefined;
}

function toSignerAddress(value: string, label: string): Hex {
  if (!isAddress(value, { strict: false })) {
    throw new Error(`The ${label} reported an invalid address: ${value}.`);
  }
  return getAddress(value);
}

/** Options that do not provide a signer: `--sender` names the sender address and `--password` only unlocks a keystore. */
const FOUNDRY_NON_SIGNER_OPTIONS = new Set(["--sender", "--password"]);

/**
 * Counts distinct signing sources requested by Foundry passthrough arguments.
 *
 * Account options accept comma lists and repeated positional values, and each
 * signing option occurrence adds a source. Foundry rotates senders across
 * broadcast transactions when more than one signer is provided, so any single
 * prediction of the diamond transaction signer could be wrong.
 *
 * @param args - Raw passthrough arguments supplied after `--`.
 * @returns The number of signing sources, treating a bare flag as one.
 */
function countFoundrySigningSources(args: string[]): number {
  let sources = 0;
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    const option = FOUNDRY_SIGNING_PASSTHROUGH_OPTIONS.find(
      (name) => argument === name || argument.startsWith(`${name}=`),
    );
    if (!option || FOUNDRY_NON_SIGNER_OPTIONS.has(option)) continue;

    if (argument.includes("=")) {
      sources += Math.max(1, argument.slice(argument.indexOf("=") + 1).split(",").filter(Boolean).length);
      continue;
    }

    let consumed = 0;
    let next = args[index + 1];
    while (next !== undefined && !next.startsWith("-")) {
      consumed += Math.max(1, next.split(",").filter(Boolean).length);
      index += 1;
      next = args[index + 1];
    }
    sources += Math.max(1, consumed);
  }
  return sources;
}

/**
 * Resolves the signer a Foundry deploy command will use.
 *
 * A Compose account supplies both the keystore name and public address.
 * Without one, Foundry uses an explicit `--sender`, or derives the sender from
 * a named `--account` keystore. When the passthrough requests more than one
 * signing source, Foundry rotates senders across transactions and no single
 * signer can be predicted, so the check is skipped rather than guessed.
 *
 * @param options - Deploy target, selected account, and framework passthrough.
 * @returns The expected signer, or null when it cannot be predicted with
 * certainty (multiple signers, an opaque method, or an interactive unlock).
 */
export async function resolveFoundryDeploySigner(
  options: DeploySignerOptions,
): Promise<Hex | null> {
  if (options.account) return getAddress(options.account.address);

  // A wrong prediction here false-fails the post-broadcast signer check after
  // gas was spent and would leave compose.lock unrecorded; null skips it.
  if (countFoundrySigningSources(options.passthrough) > 1) return null;

  const sender = readOption(options.passthrough, ["--sender"]);
  if (sender) return toSignerAddress(sender, "Foundry sender");

  const accountName = readOption(options.passthrough, ["--account", "--accounts"]);
  if (!accountName) return null;

  let addresses: string[];
  try {
    addresses = await listFoundrySignerAddresses({
      projectRoot: options.projectRoot,
      chainKey: options.chainKey,
      rpcUrl: options.rpcUrl,
      chainId: options.chainId,
      accountName: accountName.split(",")[0]?.trim(),
      allowUnlock: false,
    });
  } catch {
    // Foundry may need an interactive unlock before it exposes the address.
    return null;
  }

  const [address] = addresses;
  return address ? getAddress(address) : null;
}

/** Lists the Foundry signer address for a named keystore account. */
export async function listFoundrySignerAddresses(
  options: SignerAddressOptions,
): Promise<string[]> {
  if (!options.accountName) return [];

  const resolution = await resolveFoundryAccount(options.accountName, options.projectRoot, {
    allowUnlock: options.allowUnlock,
    onUnlock: options.onUnlock,
  });
  if (resolution.requiresUnlock) {
    throw new Error(
      `Foundry keystore account '${options.accountName}' needs to be unlocked to verify its public address. Run this command interactively or set ETH_PASSWORD to a Foundry password-file path.`,
    );
  }

  return resolution.address ? [resolution.address] : [];
}

/** Imports a key into Foundry's encrypted keystore and returns its public address. */
export async function importFoundryAccount(
  projectRoot: string,
  accountName: string,
): Promise<string | null> {
  const output = await runCommandCaptureStdout("cast", [
    "wallet",
    "import",
    accountName,
    "--interactive",
  ], {
    cwd: projectRoot,
  });
  const importedAddress = output.match(/\bAddress:\s*(0x[0-9a-fA-F]{40})\b/i)?.[1];
  if (importedAddress) return importedAddress;

  const stored = await readFoundryAccount(accountName);
  return stored.address;
}
