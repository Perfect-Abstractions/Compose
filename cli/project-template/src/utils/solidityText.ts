export type SolidityFunctionInfo = {
  name: string;
  signature: string;
  visibility: "external" | "public";
};

// Parse Solidity import specifiers from source text.
export function parseSolidityImports(soliditySource: string): string[] {
  const imports: string[] = [];
  const re = /^\s*import\s+(?:[^'"]+from\s+)?["']([^"']+)["'];/gm;
  let m: RegExpExecArray | null;
  while ((m = re.exec(soliditySource)) !== null) {
    imports.push(m[1]);
  }
  return imports;
}

// Remove block and line comments from Solidity source text.
export function removeSolidityComments(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/.*$/gm, "");
}

// Normalize one Solidity parameter type by removing location and parameter name.
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

// Parse public and external Solidity functions with normalized signatures.
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

// Parse function names exported through `this.<name>.selector` entries.
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
