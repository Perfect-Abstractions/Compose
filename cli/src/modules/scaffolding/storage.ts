import { findSolidityClosingBrace, removeSolidityComments } from "../../utils/solidityText";
import { escapeRegExp } from "../../utils/regex";
import { dedupeBy } from "../../utils/arrays";
import { StorageLayoutInfo } from "./types";

/**
 * Parses storage layouts from Solidity source code, preferring ERC-8042 annotations
 * and falling back to `.slot :=` assignment inference.
 *
 * @param source - The full Solidity source code.
 * @returns An object with parsed layouts and any warnings encountered.
 */
export function parseStorageLayouts(source: string): { layouts: StorageLayoutInfo[]; warnings: string[] } {
  const cleanSource = removeSolidityComments(source);
  const layouts: StorageLayoutInfo[] = [];
  const warnings: string[] = [];
  const structs = parseStructs(cleanSource);
  const annotationPattern = /@custom:storage-location\s+erc8042:([A-Za-z0-9_.:-]+)[\s\S]*?\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{/g;
  let match: RegExpExecArray | null;

  while ((match = annotationPattern.exec(source)) !== null) {
    layouts.push(...buildStorageLayouts(match[1], match[2], structs, "erc8042"));
  }

  if (layouts.length > 0) {
    return { layouts, warnings };
  }

  const inferredLayouts = parseSlotAssignmentLayouts(cleanSource, structs);
  if (inferredLayouts.length > 0) {
    warnings.push(
      "Missing `@custom:storage-location` annotation -- storage slot inferred from `.slot :=` pattern. Add the annotation for reliable detection.",
    );
    return { layouts: inferredLayouts, warnings };
  }

  warnings.push("Cannot determine storage layout -- no ERC-8042 annotation or recognized storage pattern found.");
  return { layouts: [], warnings };
}

/**
 * Parses all struct definitions from Solidity source, returning a map of
 * struct name to its body content.
 *
 * @param source - The Solidity source code.
 * @returns A map of struct names to their body strings.
 */
export function parseStructs(source: string): Map<string, string> {
  const structs = new Map<string, string>();
  const structPattern = /\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{/g;
  let match: RegExpExecArray | null;

  while ((match = structPattern.exec(source)) !== null) {
    const bodyStart = structPattern.lastIndex;
    const bodyEnd = findSolidityClosingBrace(source, bodyStart - 1);
    if (bodyEnd === -1) {
      continue;
    }

    structs.set(match[1], source.slice(bodyStart, bodyEnd));
    structPattern.lastIndex = bodyEnd + 1;
  }

  return structs;
}

/**
 * Builds a storage layout info entry from a slot string and struct name.
 *
 * @param slot - The storage slot identifier (e.g. "myNamespace" or "0x...").
 * @param structName - The struct name to build the layout for.
 * @param structs - Map of all parsed structs.
 * @param source - The detection source ("erc8042" or "slot-assignment").
 * @returns An array containing the single storage layout entry.
 */
export function buildStorageLayouts(
  slot: string,
  structName: string,
  structs: Map<string, string>,
  source: StorageLayoutInfo["source"],
): StorageLayoutInfo[] {
  const root = buildStructLayout(structName, structs);
  return [
    {
      slot,
      layout: root,
      source,
      structName,
    },
  ];
}

/**
 * Parses storage layouts from `.slot :=` assembly patterns within functions.
 * Infers slot namespaces from string literals, constants, or keccak256 expressions.
 *
 * @param source - The comment-stripped Solidity source code.
 * @param structs - Map of all parsed structs.
 * @returns Deduplicated array of storage layout entries.
 */
export function parseSlotAssignmentLayouts(
  source: string,
  structs: Map<string, string>,
): StorageLayoutInfo[] {
  const layouts: StorageLayoutInfo[] = [];
  const functionPattern = /\bfunction\b[\s\S]*?\{[\s\S]*?\bassembly\s*\{[\s\S]*?\.slot\s*:=[\s\S]*?\}[\s\S]*?\n\s*\}/g;
  let match: RegExpExecArray | null;

  while ((match = functionPattern.exec(source)) !== null) {
    const functionSource = match[0];
    const structName = parseReturnedStorageStruct(functionSource);
    const slotExpression = parseSlotAssignmentExpression(functionSource);

    if (!structName || !slotExpression) {
      continue;
    }

    const slot = resolveSlotNamespace(slotExpression, functionSource, source);
    if (!slot || !structs.has(structName)) {
      continue;
    }

    layouts.push(...buildStorageLayouts(slot, structName, structs, "slot-assignment"));
  }

  return dedupeStorageLayouts(layouts);
}

/**
 * Extracts the struct type name from a function's return statement
 * (e.g. `returns (MyStruct storage self)`).
 *
 * @param functionSource - The function body source code.
 * @returns The struct type name, or null if not found.
 */
export function parseReturnedStorageStruct(functionSource: string): string | null {
  const match = functionSource.match(/\breturns\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s+storage\s+[A-Za-z_][A-Za-z0-9_]*\s*\)/);
  return match?.[1] ?? null;
}

/**
 * Extracts the slot assignment expression from a `.slot :=` pattern.
 *
 * @param functionSource - The function body source code.
 * @returns The slot expression (identifier, string, or hex literal), or null.
 */
export function parseSlotAssignmentExpression(functionSource: string): string | null {
  const match = functionSource.match(/\.slot\s*:=\s*([A-Za-z_][A-Za-z0-9_]*|"[^"]+"|'[^']+'|0x[0-9a-fA-F]+)\b/);
  return match?.[1] ?? null;
}

/**
 * Resolves a slot expression to its namespace string by checking for
 * string literals, constants, local assignments, or keccak256 expressions.
 *
 * @param expression - The raw slot expression from assembly.
 * @param functionSource - The enclosing function's source code.
 * @param fullSource - The full contract source code for constant resolution.
 * @returns The resolved namespace string, or null if unresolvable.
 */
export function resolveSlotNamespace(
  expression: string,
  functionSource: string,
  fullSource: string,
): string | null {
  const directString = expression.match(/^["']([^"']+)["']$/);
  if (directString) {
    return directString[1];
  }

  const directConstant = resolveConstantNamespace(expression, fullSource);
  if (directConstant) {
    return directConstant;
  }

  const localAssignmentPattern = new RegExp(`\\bbytes32\\s+${escapeRegExp(expression)}\\s*=\\s*([^;]+);`);
  const localAssignment = functionSource.match(localAssignmentPattern);
  if (!localAssignment) {
    return null;
  }

  const localExpression = localAssignment[1].trim();
  const localKeccak = parseKeccakNamespace(localExpression);
  if (localKeccak) {
    return localKeccak;
  }

  return resolveConstantNamespace(localExpression, fullSource);
}

/**
 * Resolves a constant's value by looking up its declaration in the source
 * and extracting the keccak256 namespace string.
 *
 * @param name - The constant variable name.
 * @param source - The full contract source code.
 * @returns The keccak256 namespace string, or null if not found.
 */
export function resolveConstantNamespace(name: string, source: string): string | null {
  const constantPattern = new RegExp(`\\bbytes32\\s+(?:internal\\s+|private\\s+|public\\s+)?constant\\s+${escapeRegExp(name)}\\s*=\\s*([^;]+);`);
  const match = source.match(constantPattern);
  if (!match) {
    return null;
  }

  return parseKeccakNamespace(match[1]);
}

/**
 * Extracts the string argument from a keccak256() expression.
 *
 * @param expression - The expression to parse.
 * @returns The namespace string, or null if not a keccak256 call.
 */
export function parseKeccakNamespace(expression: string): string | null {
  const match = expression.match(/\bkeccak256\s*\(\s*["']([^"']+)["']\s*\)/);
  return match?.[1] ?? null;
}

/**
 * Deduplicates storage layouts by their slot, struct name, and layout fields.
 *
 * @param layouts - Array of storage layouts that may contain duplicates.
 * @returns Deduplicated array preserving first occurrence order.
 */
export function dedupeStorageLayouts(layouts: StorageLayoutInfo[]): StorageLayoutInfo[] {
  return dedupeBy(layouts, (layout) => `${layout.slot}:${layout.structName ?? ""}:${layout.layout.join(",")}`);
}

/**
 * Recursively builds a flattened storage layout array from a struct definition.
 * Nested structs are inlined; primitive types become storage type tokens.
 *
 * @param structName - The root struct name to build the layout for.
 * @param structs - Map of all parsed structs.
 * @returns Flattened array of storage type tokens.
 */
export function buildStructLayout(
  structName: string,
  structs: Map<string, string>,
): string[] {
  const body = structs.get(structName);
  if (!body) {
    return [];
  }

  const layout: string[] = [];

  for (const field of parseStructFields(body)) {
    const fieldType = normalizeStorageType(field.type);

    if (structs.has(fieldType)) {
      const inlineLayout = buildStructLayout(fieldType, structs);
      layout.push(...inlineLayout);
      continue;
    }

    layout.push(storageTypeToken(fieldType));
  }

  return layout;
}

/**
 * Parses the body of a Solidity struct into typed field entries.
 *
 * @param body - The struct body content (between braces).
 * @returns Array of parsed fields with type and name.
 */
export function parseStructFields(body: string): { type: string; name: string }[] {
  return body
    .split(";")
    .map((rawField) => rawField.trim())
    .filter(Boolean)
    .map((field) => field.replace(/\s+/g, " "))
    .map((field) => {
      const match = field.match(/^(.+)\s+([A-Za-z_][A-Za-z0-9_]*)$/);
      if (!match) {
        return null;
      }

      return { type: match[1], name: match[2] };
    })
    .filter((field): field is { type: string; name: string } => field !== null);
}

/**
 * Normalizes a Solidity type string by removing data location and index modifiers.
 *
 * @param type - The raw type string.
 * @returns The normalized type string.
 */
export function normalizeStorageType(type: string): string {
  return type
    .replace(/\b(calldata|memory|storage|indexed)\b/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Converts a Solidity type to a canonical storage type token.
 * Normalizes uint/int shorthand, strips variable names, and removes whitespace.
 *
 * @param type - The raw Solidity type string.
 * @returns The canonical storage type token.
 */
export function storageTypeToken(type: string): string {
  let normalized = normalizeStorageType(type)
    .replace(/\buint\b/g, "uint256")
    .replace(/\bint\b/g, "int256")
    .replace(/\s+/g, " ")
    .trim();

  normalized = stripStorageVariableNames(normalized);
  normalized = normalized
    .replace(/\s*=>\s*/g, "=>")
    .replace(/\s*,\s*/g, ",")
    .replace(/\s+/g, "");

  return normalized;
}

/**
 * Removes variable names from a Solidity type expression, keeping only
 * the type structure (handles mappings, arrays, and nested types).
 *
 * @param type - The type string potentially containing variable names.
 * @returns The type string with variable names removed.
 */
export function stripStorageVariableNames(type: string): string {
  let current = type;
  let previous: string;

  do {
    previous = current;
    current = current.replace(
      /\b([A-Za-z_][A-Za-z0-9_]*(?:[0-9]+)?(?:\[[^\]]*\])?)\s+[A-Za-z_][A-Za-z0-9_]*(?=\s*(?:=>|,|\)|$))/g,
      "$1",
    );
  } while (current !== previous);

  return current;
}
