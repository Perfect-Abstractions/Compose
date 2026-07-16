import { escapeRegExp } from "./regex";

/**
 * Describes a parsed public or external Solidity function.
 */
export type SolidityFunctionInfo = {
  /** The function name. */
  name: string;
  /** The normalized canonical signature (e.g., `transfer(address,uint256)`). */
  signature: string;
  /** The function visibility. */
  visibility: "external" | "public";
};

/**
 * Parses Solidity import specifiers from source text.
 * Supports both plain and named (`from`) import forms.
 *
 * @param soliditySource - The Solidity source code to parse.
 * @returns An array of import specifier strings (e.g., `"./Foo.sol"`).
 */
export function parseSolidityImports(soliditySource: string): string[] {
  const imports: string[] = [];
  const re = /^\s*import\s+(?:[^'"]+from\s+)?["']([^"']+)["'];/gm;
  let m: RegExpExecArray | null;
  while ((m = re.exec(soliditySource)) !== null) {
    imports.push(m[1]);
  }
  return imports;
}

/**
 * Removes block and line comments from Solidity source text.
 *
 * @param source - The raw Solidity source code.
 * @returns The source with all comments stripped.
 */
export function removeSolidityComments(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/.*$/gm, "");
}

/**
 * Extracts the body of a named Solidity contract, ignoring braces in comments and strings.
 *
 * @param source - The full Solidity source code.
 * @param contractName - The contract name to extract.
 * @returns The contract body text (without outer braces), or `null` if not found.
 */
export function extractSolidityContractBody(source: string, contractName: string): string | null {
  const declarationPattern = new RegExp(
    `\\b(?:abstract\\s+)?contract\\s+${escapeRegExp(contractName)}\\b[^\\{]*\\{`,
  );
  const declaration = declarationPattern.exec(source);
  if (!declaration) {
    return null;
  }

  const openBraceIndex = declaration.index + declaration[0].lastIndexOf("{");
  const closeBraceIndex = findSolidityClosingBrace(source, openBraceIndex);
  if (closeBraceIndex === -1) {
    return null;
  }

  return source.slice(openBraceIndex + 1, closeBraceIndex);
}

/**
 * Normalizes a single Solidity parameter type by removing data location and parameter name.
 * For example, `uint256 memory data` becomes `uint256`.
 *
 * @param parameter - A raw parameter declaration string.
 * @returns The normalized type string.
 */
export function normalizeSolidityParameterType(parameter: string): string {
  const withoutName = parameter
    .trim()
    .replace(/\s+/g, " ")
    .replace(/\b(calldata|memory|storage|indexed)\b/g, "")
    .trim();

  const parts = withoutName.split(" ").filter(Boolean);
  if (parts.length <= 1) {
    return withoutName;
  }

  return parts.slice(0, -1).join(" ");
}

/**
 * Parses public and external Solidity functions with normalized signatures.
 *
 * @param source - The Solidity source code (comments are stripped internally).
 * @returns An array of parsed function info objects.
 */
export function parseSolidityFunctions(source: string): SolidityFunctionInfo[] {
  const cleanSource = removeSolidityComments(source);
  const functions: SolidityFunctionInfo[] = [];
  const functionPattern = /\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*([^;{]*)/g;
  let match: RegExpExecArray | null;

  while ((match = functionPattern.exec(cleanSource)) !== null) {
    const [, name, rawParameters, tail] = match;
    const visibilityMatch = tail.match(/\b(external|public)\b/);
    if (!visibilityMatch || name === "exportSelectors") {
      continue;
    }

    const parameterTypes = rawParameters
      .split(",")
      .map((parameter) => parameter.trim())
      .filter(Boolean)
      .map(normalizeSolidityParameterType);

    functions.push({
      name,
      signature: `${name}(${parameterTypes.join(",")})`,
      visibility: visibilityMatch[1] as "external" | "public",
    });
  }

  return functions;
}

/**
 * Parses function names exported through `this.<name>.selector` entries
 * in the `exportSelectors` function body.
 *
 * @param source - The Solidity source code.
 * @returns An array of exported function names.
 */
export function parseExportedSelectorNames(source: string): string[] {
  const cleanSource = removeSolidityComments(source);
  const exportMatch = cleanSource.match(/\bfunction\s+exportSelectors\s*\([^)]*\)[^{;]*\{([\s\S]*?)\n\s*\}/);
  if (!exportMatch) {
    return [];
  }

  const exported = new Set<string>();
  const selectorPattern = /\bthis\.([A-Za-z_][A-Za-z0-9_]*)\.selector\b/g;
  let match: RegExpExecArray | null;

  while ((match = selectorPattern.exec(exportMatch[1])) !== null) {
    exported.add(match[1]);
  }

  return [...exported];
}

/**
 * Parses canonical signatures exported through selector references and explicit keccak256 hashes
 * in the `exportSelectors` function body.
 *
 * @param source - The Solidity source code.
 * @param functions - The parsed function info array (used to resolve selector names to signatures).
 * @returns An array of canonical signature strings (e.g., `"transfer(address,uint256)"`).
 */
export function parseExportedSelectorSignatures(
  source: string,
  functions: SolidityFunctionInfo[],
): string[] {
  const cleanSource = removeSolidityComments(source);
  const exportMatch = cleanSource.match(/\bfunction\s+exportSelectors\s*\([^)]*\)[^{;]*\{([\s\S]*?)\n\s*\}/);
  if (!exportMatch) {
    return [];
  }

  const exported = new Set<string>();
  const selectorPattern = /\bthis\.([A-Za-z_][A-Za-z0-9_]*)\.selector\b/g;
  let match: RegExpExecArray | null;

  while ((match = selectorPattern.exec(exportMatch[1])) !== null) {
    for (const fn of functions.filter((candidate) => candidate.name === match?.[1])) {
      exported.add(fn.signature);
    }
  }

  const hashedSignaturePattern = /\bbytes4\s*\(\s*keccak256\s*\(\s*["']([^"']+)["']\s*\)\s*\)/g;
  while ((match = hashedSignaturePattern.exec(exportMatch[1])) !== null) {
    exported.add(match[1].replace(/\s+/g, ""));
  }

  return [...exported];
}

/**
 * Finds the matching closing brace index for an opening brace, skipping braces
 * inside comments and string literals.
 *
 * @param source - The full Solidity source text.
 * @param openBraceIndex - The index of the opening brace.
 * @returns The index of the matching closing brace, or `-1` if unmatched.
 */
export function findSolidityClosingBrace(source: string, openBraceIndex: number): number {
  let depth = 0;
  let quote: '"' | "'" | null = null;
  let inLineComment = false;
  let inBlockComment = false;

  for (let index = openBraceIndex; index < source.length; index++) {
    const current = source[index];
    const next = source[index + 1];

    if (inLineComment) {
      if (current === "\n") inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (current === "*" && next === "/") {
        inBlockComment = false;
        index++;
      }
      continue;
    }
    if (quote) {
      if (current === "\\") {
        index++;
      } else if (current === quote) {
        quote = null;
      }
      continue;
    }
    if (current === "/" && next === "/") {
      inLineComment = true;
      index++;
      continue;
    }
    if (current === "/" && next === "*") {
      inBlockComment = true;
      index++;
      continue;
    }
    if (current === '"' || current === "'") {
      quote = current;
      continue;
    }
    if (current === "{") {
      depth++;
    } else if (current === "}") {
      depth--;
      if (depth === 0) return index;
    }
  }

  return -1;
}
