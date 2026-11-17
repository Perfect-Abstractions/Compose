/**
 * Solidity identifiers are restricted to ASCII letters, digits, underscores,
 * and (per the Solidity grammar) dollar signs, and cannot start with a digit.
 * Generated artifacts only accept the conservative subset used by this CLI.
 */
const SOLIDITY_IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_]*$/;

/**
 * Returns whether a string contains characters that can terminate or escape a
 * Solidity string literal, including quotes, backslashes, control characters,
 * and Unicode line separators.
 */
function hasUnsafeImportCharacter(value: string): boolean {
  if (value.includes('"') || value.includes("\\")) return true;
  for (const character of value) {
    const codePoint = character.codePointAt(0) ?? 0;
    if (
      codePoint <= 0x1f
      || (codePoint >= 0x7f && codePoint <= 0x9f)
      || codePoint === 0x2028
      || codePoint === 0x2029
    ) {
      return true;
    }
  }
  return false;
}

/**
 * Checks whether a value can be inserted into generated code as a Solidity
 * identifier or type name.
 *
 * @param value - The candidate identifier.
 * @returns `true` when the value matches the accepted identifier grammar.
 */
export function isSolidityIdentifier(value: string): boolean {
  return SOLIDITY_IDENTIFIER.test(value);
}

/**
 * Rejects contract names that cannot be safely embedded in generated Solidity
 * or TypeScript artifacts.
 *
 * @param value - The contract name from project configuration or resolution.
 * @param context - Human-readable location of the value, used in the error.
 * @throws {Error} If the value is not a Solidity identifier.
 */
export function assertSolidityContractName(value: string, context: string): void {
  if (!isSolidityIdentifier(value)) {
    throw new Error(
      `Invalid Solidity contract name for ${context}: ${JSON.stringify(value)}. `
      + "Use only ASCII letters, digits, and underscores, starting with a letter or underscore.",
    );
  }
}

/**
 * Rejects import specifiers that cannot be safely embedded in a generated
 * Solidity or TypeScript string literal.
 *
 * @param value - The import specifier resolved from a source path.
 * @param context - Human-readable location of the value, used in the error.
 * @throws {Error} If the value is empty or contains quotes, backslashes, or
 *   control characters.
 */
export function assertSafeSolidityImportSpec(value: string, context: string): void {
  if (!value || hasUnsafeImportCharacter(value)) {
    throw new Error(
      `Invalid Solidity import path for ${context}: ${JSON.stringify(value)}. `
      + "Quotes, backslashes, and control characters are not allowed.",
    );
  }
}
