const REDACTED = "[REDACTED]";

const SENSITIVE_FLAG_PATTERN = new RegExp(
  [
    "(?:^|[-_])(?:api|access|private|secret|signing)?keys?(?:$|[-_])",
    "mnemonic",
    "pass(?:word|phrase|wd)",
    "pwd",
    "secret",
    "token",
    "credential",
    "auth",
    "jwt",
  ].join("|"),
  "i",
);

const SENSITIVE_VALUE_FLAGS = new Set([
  "--endpoint",
  "--eth-rpc-url",
  "--fork-url",
  "--keystore",
  "--keystores",
  "--rpc-url",
  "--url",
]);

function isSensitiveFlag(flag: string): boolean {
  if (SENSITIVE_VALUE_FLAGS.has(flag.toLowerCase())) return true;
  const normalized = flag
    .replace(/^--?/, "")
    .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
    .toLowerCase();
  return SENSITIVE_FLAG_PATTERN.test(normalized);
}

/**
 * Redacts values attached to sensitive command-line flags.
 *
 * Handles both `--private-key secret` and `--private-key=secret`, and keeps
 * redacting consecutive values for flags that accept multiple secrets.
 *
 * @param args - Command arguments to redact.
 * @returns A copy of the arguments with secret values replaced.
 */
export function redactCommandArgs(args: readonly string[]): string[] {
  const redacted: string[] = [];
  let redactingValues = false;

  for (const argument of args) {
    const isOption = argument.startsWith("-") && argument !== "-";
    if (redactingValues && isOption) redactingValues = false;

    if (redactingValues) {
      redacted.push(REDACTED);
      continue;
    }

    const equalsIndex = isOption ? argument.indexOf("=") : -1;
    if (equalsIndex === -1) {
      redacted.push(argument);
      if (isOption && isSensitiveFlag(argument)) redactingValues = true;
      continue;
    }

    const flag = argument.slice(0, equalsIndex);
    redacted.push(
      isSensitiveFlag(flag) ? `${flag}=${REDACTED}` : argument,
    );
  }

  return redacted;
}

/**
 * Formats command arguments for display without exposing sensitive values.
 *
 * @param args - Command arguments to format.
 * @returns A space-separated, redacted argument string.
 */
export function formatCommandArgs(args: readonly string[]): string {
  return redactCommandArgs(args).join(" ");
}

/**
 * Redacts a single argument if it attaches a value to a sensitive flag.
 *
 * @param argument - Argument to redact.
 * @returns The original argument or its redacted form.
 */
export function redactSensitiveArgument(argument: string): string {
  return redactCommandArgs([argument])[0] ?? argument;
}
