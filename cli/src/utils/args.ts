import { redactSensitiveArgument } from "./redaction";

/**
 * Normalizes parsed `--` passthrough arguments.
 *
 * Commander exposes the tail after `--` as `unknown`; only string entries can
 * be forwarded to a framework command.
 *
 * @param value - The raw passthrough value from the parsed CLI flags.
 * @returns The string arguments in their original order.
 */
export function toPassthroughArgs(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

/**
 * Prevents framework passthrough flags from silently changing the planned
 * deployment endpoint or chain selection.
 *
 * @param passthrough - Raw arguments supplied after `--`.
 * @param framework - Framework running the managed deployment.
 * @throws {Error} If a passthrough argument conflicts with Compose's target.
 */
export function assertNoDeploymentNetworkOverrides(
  passthrough: unknown,
  framework: "foundry" | "hardhat",
  accountSelected = false,
  mode: "prepare" | "simulate" | "broadcast" = "prepare",
): void {
  const networkOptions = framework === "foundry"
    ? ["--rpc-url", "--fork-url", "--chain-id"]
    : ["--network", "--rpc-url"];
  const accountOptions = framework === "foundry"
    ? ["--account", "--private-key", "--private-keys", "--mnemonic", "--mnemonics", "--keystore", "--keystores", "--password", "--sender", "--ledger", "--trezor", "--aws", "--gcp", "--turnkey", "--unlocked"]
    : ["--account"];
  const args = toPassthroughArgs(passthrough);
  const conflictingBroadcastOption = args.find((argument) =>
    argument === "--broadcast" || argument.startsWith("--broadcast="));
  if (conflictingBroadcastOption) {
    throw new Error(
      `Framework passthrough '${redactSensitiveArgument(conflictingBroadcastOption)}' cannot change Compose deploy mode. `
      + "Use compose deploy --broadcast to send transactions.",
    );
  }

  if (mode === "simulate" && framework === "foundry") {
    if (args.some((argument) => argument === "--skip-simulation")) {
      throw new Error("Framework passthrough '--skip-simulation' disables the requested dry-run.");
    }
    const signingOption = args.find((argument) =>
      accountOptions
        .filter((option) => option !== "--sender")
        .some((option) => argument === option || argument.startsWith(`${option}=`)));
    if (signingOption) {
      throw new Error(
        `Framework passthrough '${redactSensitiveArgument(signingOption)}' is not used for a dry-run. `
        + "Select a Compose account with --account or use a public --sender address after '--'.",
      );
    }
    if (!accountSelected && !args.some((argument) =>
      argument === "--sender" || argument.startsWith("--sender="))) {
      throw new Error(
        "Foundry dry-run needs the intended public sender address. Use --account <alias> or pass --sender <address> after '--'.",
      );
    }
  }
  const conflictingNetworkOption = args.find((argument) =>
    networkOptions.some((option) => argument === option || argument.startsWith(`${option}=`)));

  if (conflictingNetworkOption) {
    throw new Error(
      `Framework passthrough '${redactSensitiveArgument(conflictingNetworkOption)}' cannot change the planned deployment target. `
      + "Use compose deploy --chain <key> and --rpc-url <url> before '--'.",
    );
  }

  if (accountSelected) {
    const conflictingAccountOption = args.find((argument) =>
      accountOptions.some((option) => argument === option || argument.startsWith(`${option}=`)));
    if (conflictingAccountOption) {
      throw new Error(
        `Framework passthrough '${redactSensitiveArgument(conflictingAccountOption)}' conflicts with the selected Compose account. `
        + "Use --account <alias> before '--' to select the signer.",
      );
    }
  }
}
