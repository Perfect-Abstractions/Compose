import type { AccountChainDefault, AccountListEntry } from "./types";

/** Narrows unknown JSON values to plain object records. */
export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Returns compose.json's accounts object, or an empty object when unset. */
export function getComposeAccounts(composeJson: Record<string, unknown>): Record<string, unknown> {
  return isRecord(composeJson.accounts) ? composeJson.accounts : {};
}

/** Returns compose.json's chains object, or an empty object when unset. */
export function getComposeChains(composeJson: Record<string, unknown>): Record<string, unknown> {
  return isRecord(composeJson.chains) ? composeJson.chains : {};
}

/** Returns chain keys that point at `alias` as their default account. */
export function findDefaultChainKeys(composeJson: Record<string, unknown>, alias: string): string[] {
  return Object.entries(getComposeChains(composeJson))
    .filter(([, chain]) => isRecord(chain) && chain.account === alias)
    .map(([chainKey]) => chainKey);
}

/** Builds the alias and chain-default views used by `compose account list`. */
export function buildAccountList(composeJson: Record<string, unknown>): {
  entries: AccountListEntry[];
  defaults: AccountChainDefault[];
} {
  const entries = Object.entries(getComposeAccounts(composeJson)).map(([alias, rawProfile]) => {
    const profile = isRecord(rawProfile) ? rawProfile : {};
    const foundry = isRecord(profile.foundry) ? profile.foundry : {};

    return {
      alias,
      address: String(profile.address ?? "invalid address"),
      ...(typeof foundry.account === "string" ? { foundryAccount: foundry.account } : {}),
    };
  });

  const defaults = Object.entries(getComposeChains(composeJson)).flatMap(([chainKey, rawChain]) =>
    isRecord(rawChain) && typeof rawChain.account === "string"
      ? [{ chainKey, alias: rawChain.account }]
      : [],
  );

  return { entries, defaults };
}
