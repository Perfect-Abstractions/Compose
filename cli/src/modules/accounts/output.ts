import type {
  AccountChainDefault,
  AccountCheckSummary,
  AccountListEntry,
  AccountSetupSummary,
} from "./types";
import { dim, green } from "../../utils/terminal";

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
  console.log();
  console.log(green("Account registered"));
  console.log(`  Alias:   ${result.alias}`);
  console.log(`  Address: ${result.address}`);

  if (result.foundryAccount) {
    console.log(`  Foundry keystore: ${result.foundryAccount}`);
  }
  if (result.chainKey) {
    console.log(`  Default chain:   ${result.chainKey}`);
  }

  console.log();
  console.log(green("Next steps"));
  let step = 1;
  if (result.framework === "hardhat") {
    if (result.keyVariableName) {
      console.log(`  ${green(`${step}.`)} Store the signer key in Hardhat's keystore:`);
      console.log(`     npx hardhat keystore set ${result.keyVariableName}`);
    } else {
      const network = result.chainKey ? `'${result.chainKey}'` : "selected";
      console.log(`  ${green(`${step}.`)} Configure the ${network} network's signer in hardhat.config.ts.`);
      console.log("     Store its key using the variable or secret manager configured there.");
    }
    console.log("     Use a key whose address matches the registered public address above.");
    step += 1;
  } else if (result.foundryAccount && !result.foundryKeystoreExists) {
    console.log(`  ${green(`${step}.`)} Import the signer into Foundry's keystore:`);
    console.log(`     cast wallet import ${result.foundryAccount}`);
    console.log("     Enter the key at Foundry's prompt, not in Compose.");
    step += 1;
  }

  const checkCommand = result.chainKey
    ? `compose account check ${result.alias} --chain ${result.chainKey}`
    : `compose account check ${result.alias} --chain <chain-key>`;
  const checkDescription = result.chainKey
    ? "Verify the configured signer matches the registered address:"
    : "Choose a chain and verify the signer matches the registered address:";
  console.log(`  ${green(`${step}.`)} ${checkDescription}`);
  console.log(`     ${checkCommand}`);
  console.log();
  console.log(dim("Enter private keys only in the framework; Compose stores the public address and account reference."));
}

/** Prints the result of removing an account alias. */
export function showAccountRemoved(alias: string): void {
  console.log(`Removed Compose account alias '${alias}'. Native framework credentials were not changed.`);
}
