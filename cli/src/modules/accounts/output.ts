import type {
  AccountChainDefault,
  AccountCheckSummary,
  AccountListEntry,
  AccountSetupSummary,
} from "./types";

/** Prints the Foundry keystore unlock notice before `cast` asks for a password. */
export function showFoundryKeystoreUnlock(accountName: string): void {
  console.log(`Unlocking Foundry keystore account '${accountName}' to read its public address...`);
}

/** Prints a successful account availability check. */
export function showAccountAvailable(result: AccountCheckSummary): void {
  console.log(`Account '${result.alias}' is available on ${result.chainKey}: ${result.address}`);
}

/** Prints guidance when no Compose account aliases are configured. */
export function showNoAccounts(): void {
  console.log("No Compose account aliases are configured.");
  console.log("Run 'compose account setup <alias>' to register a framework-managed account.");
}

/** Prints configured aliases and their chain defaults. */
export function showAccountList(entries: AccountListEntry[], defaults: AccountChainDefault[]): void {
  console.log("Compose accounts:");
  for (const entry of entries) {
    console.log(`  ${entry.alias}: ${entry.address}`);
    if (entry.foundryAccount) {
      console.log(`    Foundry keystore: ${entry.foundryAccount}`);
    }
  }

  for (const chainDefault of defaults) {
    console.log(`  Default for ${chainDefault.chainKey}: ${chainDefault.alias}`);
  }
}

/** Prints the result of registering an account alias. */
export function showAccountRegistered(result: AccountSetupSummary): void {
  console.log(`Registered account '${result.alias}' at ${result.address} in compose.json.`);

  if (result.foundryAccount) {
    console.log(`Foundry signer reference: encrypted keystore account '${result.foundryAccount}'.`);
    if (!result.foundryKeystoreExists) {
      console.log(
        `Import it into Foundry's keystore before deploying with 'cast wallet import ${result.foundryAccount}'.`,
      );
    }
  }

  if (result.framework === "hardhat" && result.keyVariableName) {
    console.log(`Store the key with 'npx hardhat keystore set ${result.keyVariableName}'.`);
    console.log(
      `In hardhat.config.ts, include configVariable("${result.keyVariableName}") in the selected HTTP network's accounts.`,
    );
    console.log("Compose selects the configured signer matching the public address; it never reads the key.");
  }

  if (result.chainKey) {
    console.log(`Set '${result.alias}' as the default account for chain '${result.chainKey}'.`);
  }

  console.log("Compose stores only the public address and account reference, never key material.");
}

/** Prints the result of removing an account alias. */
export function showAccountRemoved(alias: string): void {
  console.log(`Removed Compose account alias '${alias}'. Native framework credentials were not changed.`);
}
