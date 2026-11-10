import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { getAddress, isAddress } from "viem";
import type { ComposeContext } from "../context/types";
import { assertValidAccountAlias, resolveAccountProfile } from "../modules/accounts/config";
import { detectHardhatToolbox } from "../modules/deployScript/model";
import { validateOptions } from "../adapters/IRPCAdapter/validation";
import { locateComposeProjectFile, readComposeProjectFile } from "../utils/composeProjectFile";
import { resolveChainConfig } from "../utils/chainConfig";
import { atomicWriteFile } from "../utils/files";
import { isInteractive, loadPrompts } from "../utils/inquirer";
import { runCommandCaptureStdout } from "../utils/exec";
import { FrameworkModule } from "../modules/framework/module";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

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

async function readFoundryKeystoreAddress(accountName: string): Promise<string | null> {
  const directory = foundryKeystoreDirectory();
  for (const filename of [accountName, `${accountName}.json`]) {
    try {
      const keystore = JSON.parse(await fs.readFile(path.join(directory, filename), "utf8")) as {
        address?: unknown;
      };
      if (typeof keystore.address !== "string") continue;
      const address = keystore.address.startsWith("0x") ? keystore.address : `0x${keystore.address}`;
      return isAddress(address, { strict: false }) ? getAddress(address) : null;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }
  return null;
}

async function resolveFoundryKeystoreAddress(
  accountName: string,
  projectRoot: string,
): Promise<string | null> {
  const storedAddress = await readFoundryKeystoreAddress(accountName);
  if (storedAddress) return storedAddress;

  if (!(await foundryKeystorePath(accountName)) || (!isInteractive() && !process.env.ETH_PASSWORD)) return null;

  console.log(`Unlocking Foundry keystore account '${accountName}' to read its public address...`);
  const output = await runCommandCaptureStdout(
    "cast",
    ["wallet", "address", "--account", accountName],
    { cwd: projectRoot, forwardStdout: false },
  );
  const address = output.match(/\b0x[0-9a-fA-F]{40}\b/)?.[0];
  if (!address || !isAddress(address, { strict: false })) {
    throw new Error(`Foundry did not return a public address for keystore account '${accountName}'.`);
  }
  return getAddress(address);
}

function toProjectScriptPath(projectRoot: string, scriptPath: string): string {
  return path.relative(projectRoot, scriptPath).replace(/\\/g, "/");
}

async function hardhatSignerAddresses(
  projectRoot: string,
  chainKey: string,
  rpcUrl: string,
  chainId: number,
): Promise<string[]> {
  FrameworkModule.assertHardhat3(projectRoot);
  const toolbox = await detectHardhatToolbox(projectRoot);
  const scriptPath = path.join(projectRoot, "scripts", `compose-account-check-${randomUUID()}.ts`);
  const accountRead = toolbox === "viem"
    ? 'const addresses = (await connection.viem.getWalletClients()).map((wallet) => wallet.account.address);'
    : 'const addresses = await Promise.all((await connection.ethers.getSigners()).map((signer) => signer.getAddress()));';
  const script = [
    'import { network } from "hardhat";',
    'const rpcUrl = process.env.COMPOSE_DEPLOY_RPC_URL;',
    'if (!rpcUrl) throw new Error("Compose RPC URL was not provided");',
    `const connection = await network.create({ network: ${JSON.stringify(chainKey)}, override: { url: rpcUrl } });`,
    'if (connection.networkConfig.type !== "http") throw new Error("Selected Hardhat network must be HTTP");',
    'const actualChainId = Number(BigInt(String(await connection.provider.request({ method: "eth_chainId", params: [] }))));',
    `if (actualChainId !== ${chainId}) throw new Error("Hardhat RPC chain ID does not match Compose");`,
    accountRead,
    'console.log("COMPOSE_ACCOUNT_ADDRESSES:" + JSON.stringify(addresses));',
    "await connection.close();",
  ].join("\n");

  await fs.mkdir(path.dirname(scriptPath), { recursive: true });
  await fs.writeFile(scriptPath, script, "utf8");
  try {
    const output = await runCommandCaptureStdout(
      "npx",
      ["hardhat", "run", toProjectScriptPath(projectRoot, scriptPath), "--network", chainKey],
      { cwd: projectRoot, env: { COMPOSE_DEPLOY_RPC_URL: rpcUrl } },
    );
    const marker = output.split(/\r?\n/).find((line) => line.startsWith("COMPOSE_ACCOUNT_ADDRESSES:"));
    if (!marker) throw new Error("Hardhat did not report its configured signer addresses.");
    const parsed = JSON.parse(marker.slice("COMPOSE_ACCOUNT_ADDRESSES:".length)) as unknown;
    if (!Array.isArray(parsed) || !parsed.every((address) => typeof address === "string")) {
      throw new Error("Hardhat returned an invalid signer address list.");
    }
    return parsed.map((address) => getAddress(address));
  } finally {
    await fs.rm(scriptPath, { force: true });
  }
}

async function checkAccount(
  ctx: ComposeContext,
  composeJson: Record<string, unknown>,
  projectRoot: string,
): Promise<void> {
  const alias = String(ctx.param.accountName ?? "");
  assertValidAccountAlias(alias);
  const framework = composeJson.framework;
  if (framework !== "foundry" && framework !== "hardhat") {
    throw new Error("compose.json must select the 'foundry' or 'hardhat' framework before checking accounts.");
  }
  const account = resolveAccountProfile(composeJson.accounts, alias, framework);
  const chains = isRecord(composeJson.chains) ? composeJson.chains : {};
  const requestedChain = typeof ctx.param.chain === "string" ? ctx.param.chain : undefined;
  const defaults = Object.entries(chains)
    .filter(([, chain]) => isRecord(chain) && chain.account === alias)
    .map(([chainKey]) => chainKey);
  const chainKey = requestedChain ?? (defaults.length === 1 ? defaults[0] : undefined);
  if (!chainKey) {
    throw new Error(`Pass --chain or set '${alias}' as the default account for exactly one chain.`);
  }

  const chain = await resolveChainConfig({
    chainKey,
    projectRoot,
    rpcUrlOverride: ctx.param.rpcUrl,
  });
  validateOptions({ rpcUrl: chain.rpcUrl, chainId: chain.chainId });

  let availableAddresses: string[];
  if (framework === "foundry") {
    const foundryAccount = account.foundryAccount ?? alias;
    const foundryAddress = await resolveFoundryKeystoreAddress(foundryAccount, projectRoot);
    if (!foundryAddress && await foundryKeystorePath(foundryAccount) && !isInteractive()) {
      throw new Error(
        `Foundry keystore account '${foundryAccount}' needs to be unlocked to verify its public address. Run this command interactively or set ETH_PASSWORD to a Foundry password-file path.`,
      );
    }
    availableAddresses = foundryAddress ? [foundryAddress] : [];
  } else {
    availableAddresses = await hardhatSignerAddresses(projectRoot, chainKey, chain.rpcUrl, chain.chainId);
  }

  if (!availableAddresses.some((address) => address.toLowerCase() === account.address.toLowerCase())) {
    throw new Error(
      `Account '${alias}' (${account.address}) is not available in ${framework} on chain '${chainKey}'.`,
    );
  }
  console.log(`Account '${alias}' is available on ${chainKey}: ${account.address}`);
}

async function promptPublicAddress(): Promise<string> {
  const { input } = await loadPrompts();
  return input({
    message: "Public signer address (never enter a private key):",
    validate: (value) => isAddress(value, { strict: false }) ? true : "Enter a valid EVM address.",
  });
}

function printAccounts(composeJson: Record<string, unknown>): void {
  const accounts = isRecord(composeJson.accounts) ? composeJson.accounts : {};
  const entries = Object.entries(accounts);
  if (entries.length === 0) {
    console.log("No Compose account aliases are configured.");
    console.log("Run 'compose account setup <alias>' to register a framework-managed account.");
    return;
  }

  console.log("Compose accounts:");
  for (const [alias, rawProfile] of entries) {
    const profile = isRecord(rawProfile) ? rawProfile : {};
    const foundry = isRecord(profile.foundry) ? profile.foundry : {};
    console.log(`  ${alias}: ${String(profile.address ?? "invalid address")}`);
    if (typeof foundry.account === "string") console.log(`    Foundry keystore: ${foundry.account}`);
  }

  const chains = isRecord(composeJson.chains) ? composeJson.chains : {};
  for (const [chainKey, rawChain] of Object.entries(chains)) {
    if (isRecord(rawChain) && typeof rawChain.account === "string") {
      console.log(`  Default for ${chainKey}: ${rawChain.account}`);
    }
  }
}

/** Sets up non-secret account aliases; key entry and signing stay in the framework. */
export const AccountPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    const action = String(ctx.param.action ?? "");
    const startDirectory = String(ctx.param.projectRoot ?? process.cwd());
    const composeFile = await locateComposeProjectFile(startDirectory);
    if (!composeFile) throw new Error("compose.json not found. Run 'compose init' first.");

    const parsed = await readComposeProjectFile(composeFile.path);
    if (!isRecord(parsed)) throw new Error("compose.json must contain a JSON object.");
    const composeJson: Record<string, unknown> = parsed;

    if (action === "list") {
      printAccounts(composeJson);
      return ctx;
    }
    if (action === "check") {
      await checkAccount(ctx, composeJson, composeFile.root);
      return ctx;
    }
    if (action === "remove") {
      const alias = String(ctx.param.accountName ?? "");
      assertValidAccountAlias(alias);
      const accounts = isRecord(composeJson.accounts) ? { ...composeJson.accounts } : {};
      if (!(alias in accounts)) throw new Error(`Account alias '${alias}' was not found in compose.json.`);
      delete accounts[alias];
      composeJson.accounts = accounts;
      const chains = isRecord(composeJson.chains) ? { ...composeJson.chains } : {};
      for (const [chainKey, rawChain] of Object.entries(chains)) {
        if (isRecord(rawChain) && rawChain.account === alias) {
          chains[chainKey] = Object.fromEntries(
            Object.entries(rawChain).filter(([key]) => key !== "account"),
          );
        }
      }
      composeJson.chains = chains;
      await atomicWriteFile(composeFile.path, `${JSON.stringify(composeJson, null, 2)}\n`);
      console.log(`Removed Compose account alias '${alias}'. Native framework credentials were not changed.`);
      return ctx;
    }
    if (action !== "setup") {
      throw new Error("Use 'compose account setup <alias>', 'compose account check <alias>', 'compose account list', or 'compose account remove <alias>'.");
    }

    let alias = String(ctx.param.accountName ?? "");
    if (!alias) {
      if (!isInteractive()) throw new Error("Account alias is required in non-interactive mode.");
      const { input } = await loadPrompts();
      alias = await input({
        message: "Account alias:",
        validate: (value) => {
          try {
            assertValidAccountAlias(value);
            return true;
          } catch (error) {
            return (error as Error).message;
          }
        },
      });
    }
    assertValidAccountAlias(alias);

    const framework = composeJson.framework;
    if (framework !== "foundry" && framework !== "hardhat") {
      throw new Error("compose.json must select the 'foundry' or 'hardhat' framework before setting up accounts.");
    }

    const foundryAccount = framework === "foundry"
      ? String(ctx.param.foundryAccount ?? alias)
      : undefined;
    if (foundryAccount) assertValidAccountAlias(foundryAccount);

    let updatedChains: Record<string, unknown> | undefined;
    if (ctx.param.chain !== undefined) {
      if (typeof ctx.param.chain !== "string") throw new Error("Chain key must be a string.");
      const chains = isRecord(composeJson.chains) ? { ...composeJson.chains } : {};
      const chain = chains[ctx.param.chain];
      if (!isRecord(chain)) throw new Error(`Chain '${ctx.param.chain}' was not found in compose.json.`);
      updatedChains = { ...chains, [ctx.param.chain]: { ...chain, account: alias } };
    }

    let address = typeof ctx.param.address === "string" ? ctx.param.address : "";
    if (!address && framework === "foundry") {
      const keystoreExists = Boolean(await foundryKeystorePath(foundryAccount!));
      if (keystoreExists) {
        address = await resolveFoundryKeystoreAddress(foundryAccount!, composeFile.root) ?? "";
        if (!address && !isInteractive()) {
          throw new Error(
            `Foundry keystore account '${foundryAccount}' already exists, but its address is encrypted. Run setup interactively, set ETH_PASSWORD to a Foundry password-file path, or pass its public address with --address.`,
          );
        }
      } else if (isInteractive()) {
        const { confirm } = await loadPrompts();
        const importAccount = await confirm({
          message: `Import a key into Foundry's encrypted keystore as '${foundryAccount}'?`,
          default: true,
        });
        if (!importAccount) {
          throw new Error(`Import Foundry account '${foundryAccount}' or pass its public address with --address.`);
        }
        const importOutput = await runCommandCaptureStdout("cast", [
          "wallet",
          "import",
          foundryAccount!,
          "--interactive",
        ], {
          cwd: composeFile.root,
        });
        const importedAddress = importOutput.match(/\bAddress:\s*(0x[0-9a-fA-F]{40})\b/i)?.[1];
        address = importedAddress ?? await readFoundryKeystoreAddress(foundryAccount!) ?? "";
      }
    }
    if (!address && isInteractive()) address = await promptPublicAddress();
    if (!address) {
      throw new Error("Public account address is required. Pass --address; never pass a private key to Compose.");
    }
    if (!isAddress(address, { strict: false })) throw new Error("Account address must be a valid EVM address.");
    address = getAddress(address);
    if (foundryAccount) {
      const nativeAddress = await readFoundryKeystoreAddress(foundryAccount);
      if (nativeAddress && nativeAddress.toLowerCase() !== address.toLowerCase()) {
        throw new Error(
          `Foundry keystore account '${foundryAccount}' resolves to ${nativeAddress}, not ${address}.`,
        );
      }
    }

    const accounts = isRecord(composeJson.accounts) ? { ...composeJson.accounts } : {};
    const existing = accounts[alias];
    if (isRecord(existing) && existing.address !== address) {
      throw new Error(`Account alias '${alias}' already points to ${String(existing.address)}. Choose another alias.`);
    }
    accounts[alias] = {
      address,
      ...(foundryAccount ? { foundry: { account: foundryAccount } } : {}),
    };
    composeJson.accounts = accounts;

    if (updatedChains) composeJson.chains = updatedChains;

    await atomicWriteFile(composeFile.path, `${JSON.stringify(composeJson, null, 2)}\n`);
    console.log(`Registered account '${alias}' at ${address} in compose.json.`);
    if (foundryAccount) {
      console.log(`Foundry signer reference: encrypted keystore account '${foundryAccount}'.`);
      if (!(await foundryKeystorePath(foundryAccount))) {
        console.log(`Import it into Foundry's keystore before deploying with 'cast wallet import ${foundryAccount}'.`);
      }
    }
    if (framework === "hardhat") {
      const variableName = `COMPOSE_${alias.replace(/[^A-Za-z0-9]/g, "_").toUpperCase()}_PRIVATE_KEY`;
      console.log(`Store the key with 'npx hardhat keystore set ${variableName}'.`);
      console.log(`In hardhat.config.ts, include configVariable("${variableName}") in the selected HTTP network's accounts.`);
      console.log("Compose selects the configured signer matching the public address; it never reads the key.");
    }
    if (ctx.param.chain) console.log(`Set '${alias}' as the default account for chain '${String(ctx.param.chain)}'.`);
    console.log("Compose stores only the public address and account reference, never key material.");

    return ctx;
  },
};
