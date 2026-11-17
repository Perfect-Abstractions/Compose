import { getAddress, isAddress } from "viem";
import type { ComposeContext } from "../../context/types";
import type { IFrameworkAdapter } from "../../adapters/IFrameworkAdapter/interface";
import { validateOptions } from "../../adapters/IRPCAdapter/validation";
import { resolveChainConfig } from "../../utils/chainConfig";
import { loadComposeProjectFile, type ComposeProjectFile } from "../../utils/composeProjectFile";
import { atomicWriteFile } from "../../utils/files";
import { isInteractive, loadPrompts } from "../../utils/inquirer";
import type { Framework } from "../framework/module";
import { assertValidAccountAlias, resolveAccountProfile } from "./config";
import { buildAccountList, findDefaultChainKeys, getComposeAccounts, getComposeChains, isRecord } from "./model";
import {
  showAccountAvailable,
  showAccountList,
  showAccountRegistered,
  showAccountRemoved,
  showFoundryKeystoreUnlock,
  showNoAccounts,
} from "./output";
import type { AccountActionResult, AccountCheckSummary, AccountSetupSummary } from "./types";

/** Loaded compose.json state for one account command. */
export type AccountProject = {
  composeFile: ComposeProjectFile;
  composeJson: Record<string, unknown>;
};

/** Framework state the pipeline resolves before check/setup execution. */
export type AccountDependencies = {
  framework: Framework;
  adapter: IFrameworkAdapter;
};

function requireAccountDependencies(
  dependencies: AccountDependencies | undefined,
): AccountDependencies {
  if (!dependencies) throw new Error("The account framework adapter was not resolved.");
  return dependencies;
}

async function writeComposeFile(
  composeFile: ComposeProjectFile,
  composeJson: Record<string, unknown>,
): Promise<void> {
  await atomicWriteFile(composeFile.path, `${JSON.stringify(composeJson, null, 2)}\n`);
}

async function promptPublicAddress(): Promise<string> {
  const { input } = await loadPrompts();
  return input({
    message: "Public signer address (never enter a private key):",
    validate: (value) => isAddress(value, { strict: false }) ? true : "Enter a valid EVM address.",
  });
}

async function checkAccount(
  ctx: ComposeContext,
  composeJson: Record<string, unknown>,
  projectRoot: string,
  framework: Framework,
  adapter: IFrameworkAdapter,
): Promise<AccountCheckSummary> {
  const alias = String(ctx.param.accountName ?? "");
  assertValidAccountAlias(alias);
  const account = resolveAccountProfile(composeJson.accounts, alias, framework);
  const requestedChain = typeof ctx.param.chain === "string" ? ctx.param.chain : undefined;
  const defaults = findDefaultChainKeys(composeJson, alias);
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

  const nativeAccount = account.foundryAccount ?? alias;
  const availableAddresses = await adapter.listSignerAddresses({
    projectRoot,
    chainKey,
    rpcUrl: chain.rpcUrl,
    chainId: chain.chainId,
    accountName: nativeAccount,
    allowUnlock: isInteractive() || Boolean(process.env.ETH_PASSWORD),
    onUnlock: () => showFoundryKeystoreUnlock(nativeAccount),
  });

  if (!availableAddresses.some((address) => address.toLowerCase() === account.address.toLowerCase())) {
    throw new Error(
      `Account '${alias}' (${account.address}) is not available in ${framework} on chain '${chainKey}'.`,
    );
  }
  const summary = { alias, address: account.address, chainKey };
  showAccountAvailable(summary);
  return summary;
}

function listAccounts(composeJson: Record<string, unknown>): AccountActionResult {
  const { entries, defaults } = buildAccountList(composeJson);
  if (entries.length === 0) {
    showNoAccounts();
  } else {
    showAccountList(entries, defaults);
  }
  return { action: "list", entries, defaults };
}

async function removeAccount(
  composeJson: Record<string, unknown>,
  composeFile: ComposeProjectFile,
  alias: string,
): Promise<void> {
  const accounts = { ...getComposeAccounts(composeJson) };
  if (!(alias in accounts)) throw new Error(`Account alias '${alias}' was not found in compose.json.`);
  delete accounts[alias];
  composeJson.accounts = accounts;

  const chains = { ...getComposeChains(composeJson) };
  for (const [chainKey, rawChain] of Object.entries(chains)) {
    if (isRecord(rawChain) && rawChain.account === alias) {
      chains[chainKey] = Object.fromEntries(
        Object.entries(rawChain).filter(([key]) => key !== "account"),
      );
    }
  }
  composeJson.chains = chains;

  await writeComposeFile(composeFile, composeJson);
  showAccountRemoved(alias);
}

async function setupAccount(
  ctx: ComposeContext,
  composeJson: Record<string, unknown>,
  composeFile: ComposeProjectFile,
  framework: Framework,
  adapter: IFrameworkAdapter,
): Promise<AccountSetupSummary> {
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

  const foundryAccount = framework === "foundry"
    ? String(ctx.param.foundryAccount ?? alias)
    : undefined;
  if (foundryAccount) assertValidAccountAlias(foundryAccount);

  const nativeAccount = foundryAccount ?? alias;
  const allowUnlock = isInteractive() || Boolean(process.env.ETH_PASSWORD);

  let updatedChains: Record<string, unknown> | undefined;
  if (ctx.param.chain !== undefined) {
    if (typeof ctx.param.chain !== "string") throw new Error("Chain key must be a string.");
    const chains = { ...getComposeChains(composeJson) };
    const chain = chains[ctx.param.chain];
    if (!isRecord(chain)) throw new Error(`Chain '${ctx.param.chain}' was not found in compose.json.`);
    updatedChains = { ...chains, [ctx.param.chain]: { ...chain, account: alias } };
  }

  let address = typeof ctx.param.address === "string" ? ctx.param.address : "";
  if (!address) {
    const resolution = await adapter.resolveAccountAddress(composeFile.root, nativeAccount, {
      allowUnlock,
      onUnlock: () => showFoundryKeystoreUnlock(nativeAccount),
    });
    address = resolution.address ?? "";
    if (!address && resolution.requiresUnlock && !allowUnlock) {
      throw new Error(
        `Foundry keystore account '${nativeAccount}' already exists, but its address is encrypted. Run setup interactively, set ETH_PASSWORD to a Foundry password-file path, or pass its public address with --address.`,
      );
    }
    if (!address && adapter.supportsAccountImport && isInteractive()) {
      const { confirm } = await loadPrompts();
      const importAccount = await confirm({
        message: `Import a key into Foundry's encrypted keystore as '${nativeAccount}'?`,
        default: true,
      });
      if (!importAccount) {
        throw new Error(`Import Foundry account '${nativeAccount}' or pass its public address with --address.`);
      }
      address = await adapter.importAccount(composeFile.root, nativeAccount) ?? "";
    }
  }
  if (!address && isInteractive()) address = await promptPublicAddress();
  if (!address) {
    throw new Error("Public account address is required. Pass --address; never pass a private key to Compose.");
  }
  if (!isAddress(address, { strict: false })) throw new Error("Account address must be a valid EVM address.");
  address = getAddress(address);

  const native = await adapter.readAccountAddress(composeFile.root, nativeAccount);
  if (native.address && native.address.toLowerCase() !== address.toLowerCase()) {
    throw new Error(
      `Foundry keystore account '${nativeAccount}' resolves to ${native.address}, not ${address}.`,
    );
  }

  const chainKey = typeof ctx.param.chain === "string" && ctx.param.chain
    ? ctx.param.chain
    : undefined;
  const keyVariableName = framework === "hardhat" && chainKey
    ? await adapter.getAccountKeyVariable?.(composeFile.root, chainKey) ?? undefined
    : undefined;

  const accounts = { ...getComposeAccounts(composeJson) };
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

  await writeComposeFile(composeFile, composeJson);

  const summary: AccountSetupSummary = {
    alias,
    address,
    framework,
    ...(foundryAccount ? { foundryAccount } : {}),
    foundryKeystoreExists: native.exists,
    ...(keyVariableName ? { keyVariableName } : {}),
    ...(chainKey ? { chainKey } : {}),
  };
  showAccountRegistered(summary);
  return summary;
}

/** Manages non-secret account aliases; key entry and signing stay in the framework. */
export const AccountModule = {
  /**
   * Loads the nearest compose.json and validates that it contains an object.
   *
   * @param ctx - The compose context with an optional project root.
   * @returns The compose file location and parsed object.
   */
  async loadProject(ctx: ComposeContext): Promise<AccountProject> {
    const startDirectory = String(ctx.param.projectRoot ?? process.cwd());
    const loaded = await loadComposeProjectFile(startDirectory);
    if (!loaded) throw new Error("compose.json not found. Run 'compose init' first.");
    if (!isRecord(loaded.composeJson)) {
      throw new Error("compose.json must contain a JSON object.");
    }

    return {
      composeFile: { path: loaded.path, root: loaded.root },
      composeJson: loaded.composeJson,
    };
  },

  /**
   * Runs the requested account action against compose.json and records the
   * outcome in `ctx.state.account`.
   *
   * Check and setup require the pipeline-resolved framework adapter. List and
   * remove do not touch the framework.
   *
   * @param ctx - The compose context with `action`, `accountName`, and command flags.
   * @param project - The loaded compose.json project.
   * @param dependencies - Framework state resolved by the pipeline for check/setup.
   * @returns The context with `state.account` populated on success.
   */
  async execute(
    ctx: ComposeContext,
    project: AccountProject,
    dependencies?: AccountDependencies,
  ): Promise<ComposeContext> {
    const action = String(ctx.param.action ?? "");
    const { composeFile, composeJson } = project;

    let result: AccountActionResult;
    if (action === "list") {
      result = listAccounts(composeJson);
    } else if (action === "check") {
      const resolved = requireAccountDependencies(dependencies);
      result = {
        action: "check",
        ...await checkAccount(ctx, composeJson, composeFile.root, resolved.framework, resolved.adapter),
      };
    } else if (action === "remove") {
      const alias = String(ctx.param.accountName ?? "");
      assertValidAccountAlias(alias);
      await removeAccount(composeJson, composeFile, alias);
      result = { action: "remove", alias };
    } else {
      if (action !== "setup") {
        throw new Error("Use 'compose account setup <alias>', 'compose account check <alias>', 'compose account list', or 'compose account remove <alias>'.");
      }
      const resolved = requireAccountDependencies(dependencies);
      result = {
        action: "setup",
        ...await setupAccount(ctx, composeJson, composeFile, resolved.framework, resolved.adapter),
      };
    }

    ctx.state.account = { success: true, result, error: null };
    return ctx;
  },
};
