import { getAddress, isAddress } from "viem";
import type { DeploymentAccount } from "./types";

const ACCOUNT_ALIAS_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;
const RESERVED_ACCOUNT_ALIASES = new Set(["__proto__", "constructor", "prototype"]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Ensures an alias is safe to use as a compose.json object key. */
export function assertValidAccountAlias(alias: string): void {
  if (!ACCOUNT_ALIAS_PATTERN.test(alias) || RESERVED_ACCOUNT_ALIASES.has(alias)) {
    throw new Error(
      `Invalid account alias '${alias}'. Use letters, digits, '.', '_' or '-' and avoid reserved object keys.`,
    );
  }
}

/** Resolves and validates a non-secret signer profile from compose.json. */
export function resolveAccountProfile(
  accounts: unknown,
  alias: string,
  framework: "foundry" | "hardhat",
): DeploymentAccount {
  assertValidAccountAlias(alias);
  if (!isRecord(accounts)) throw new Error("compose.json does not define any account profiles.");

  const rawProfile = accounts[alias];
  if (!isRecord(rawProfile)) throw new Error(`Account alias '${alias}' was not found in compose.json.`);
  if (typeof rawProfile.address !== "string" || !isAddress(rawProfile.address, { strict: false })) {
    throw new Error(`Account '${alias}' must define a valid public address.`);
  }

  let foundryAccount: string | undefined;
  if (framework === "foundry") {
    if (rawProfile.foundry !== undefined && !isRecord(rawProfile.foundry)) {
      throw new Error(`Account '${alias}' has an invalid Foundry account reference.`);
    }
    const foundry = isRecord(rawProfile.foundry) ? rawProfile.foundry : undefined;
    if (foundry?.account !== undefined && (typeof foundry.account !== "string" || !foundry.account.trim())) {
      throw new Error(`Account '${alias}' has an invalid Foundry account name.`);
    }
    foundryAccount = typeof foundry?.account === "string" ? foundry.account.trim() : alias;
    assertValidAccountAlias(foundryAccount);
  }

  return {
    alias,
    address: getAddress(rawProfile.address),
    ...(foundryAccount ? { foundryAccount } : {}),
  };
}
