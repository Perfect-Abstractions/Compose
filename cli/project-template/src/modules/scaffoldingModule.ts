import fs from "node:fs/promises";
import path from "node:path";
import { ComposeContext } from "../context/types";
import { BasesCatalog, FacetEntry } from "./configModule";
import {
  copyFileIfMissing,
  resolveLocalSolidityImportClosure,
  writeFileIfMissing,
} from "../utils/files";
import { escapeRegExp } from "../utils/regex";
import {
  parseExportedSelectorNames,
  parseSolidityFunctions,
  removeSolidityComments,
  type SolidityFunctionInfo,
} from "../utils/solidityText";

// =====================
// Helper
// =====================

type SeedFile = {
  source: string;
  target: string;
};

type SelectedFacetSource =
  | "diamond-required"
  | "diamond-optional"
  | "library-required"
  | "base-required"
  | "library-optional"
  | "extension"
  | "local-example";

type SelectedFacet = {
  name: string;
  source: SelectedFacetSource;
  entry: FacetEntry;
};

type StorageLayoutInfo = {
  slot: string;
  layout: string[];
  source: "erc8042" | "slot-assignment";
  structName: string | null;
};

type FacetScanResult = {
  facetName: string;
  source: SelectedFacetSource;
  path: string;
  contractName: string | null;
  functions: SolidityFunctionInfo[];
  exportedSelectors: string[];
  missingExports: string[];
  extraExports: string[];
  storageLayouts: StorageLayoutInfo[];
  warnings: string[];
};

// Extract storage layouts using M1's annotation-first, slot-assignment fallback rule.
function parseStorageLayouts(source: string): { layouts: StorageLayoutInfo[]; warnings: string[] } {
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

// Collect struct bodies by name so storage layout parsing can resolve fields.
function parseStructs(source: string): Map<string, string> {
  const structs = new Map<string, string>();
  const structPattern = /\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{/g;
  let match: RegExpExecArray | null;

  while ((match = structPattern.exec(source)) !== null) {
    const bodyStart = structPattern.lastIndex;
    const bodyEnd = findMatchingBrace(source, bodyStart - 1);
    if (bodyEnd === -1) {
      continue;
    }

    structs.set(match[1], source.slice(bodyStart, bodyEnd));
    structPattern.lastIndex = bodyEnd + 1;
  }

  return structs;
}

// Find the closing brace that matches the given opening brace index.
function findMatchingBrace(source: string, openBraceIndex: number): number {
  let depth = 0;
  for (let i = openBraceIndex; i < source.length; i++) {
    if (source[i] === "{") {
      depth++;
      continue;
    }

    if (source[i] === "}") {
      depth--;
      if (depth === 0) {
        return i;
      }
    }
  }

  return -1;
}

// Build the storage layout record for one namespace and struct pair.
function buildStorageLayouts(
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

// Infer storage layout records from accessor functions that assign `.slot`.
function parseSlotAssignmentLayouts(
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

// Read the storage struct returned by an accessor function.
function parseReturnedStorageStruct(functionSource: string): string | null {
  const match = functionSource.match(/\breturns\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s+storage\s+[A-Za-z_][A-Za-z0-9_]*\s*\)/);
  return match?.[1] ?? null;
}

// Read the expression assigned to `.slot` inside an assembly block.
function parseSlotAssignmentExpression(functionSource: string): string | null {
  const match = functionSource.match(/\.slot\s*:=\s*([A-Za-z_][A-Za-z0-9_]*|"[^"]+"|'[^']+'|0x[0-9a-fA-F]+)\b/);
  return match?.[1] ?? null;
}

// Resolve a `.slot` assignment expression back to its namespace string.
function resolveSlotNamespace(
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

// Resolve a bytes32 constant declaration into its keccak namespace.
function resolveConstantNamespace(name: string, source: string): string | null {
  const constantPattern = new RegExp(`\\bbytes32\\s+(?:internal\\s+|private\\s+|public\\s+)?constant\\s+${escapeRegExp(name)}\\s*=\\s*([^;]+);`);
  const match = source.match(constantPattern);
  if (!match) {
    return null;
  }

  return parseKeccakNamespace(match[1]);
}

// Extract the string namespace from a `keccak256("...")` expression.
function parseKeccakNamespace(expression: string): string | null {
  const match = expression.match(/\bkeccak256\s*\(\s*["']([^"']+)["']\s*\)/);
  return match?.[1] ?? null;
}

// Remove duplicate storage layout records produced by repeated source patterns.
function dedupeStorageLayouts(layouts: StorageLayoutInfo[]): StorageLayoutInfo[] {
  const seen = new Set<string>();
  return layouts.filter((layout) => {
    const key = `${layout.slot}:${layout.structName ?? ""}:${layout.layout.join(",")}`;
    if (seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
}

// Flatten a struct into the normalized storage type sequence used by validation.
function buildStructLayout(
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

// Split a Solidity struct body into field type/name pairs.
function parseStructFields(body: string): { type: string; name: string }[] {
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

// Remove Solidity storage-location keywords from a type string.
function normalizeStorageType(type: string): string {
  return type
    .replace(/\b(calldata|memory|storage|indexed)\b/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

// Normalize a Solidity storage type for layout comparison.
function storageTypeToken(type: string): string {
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

// Remove mapping parameter names so equivalent mapping types compare equally.
function stripStorageVariableNames(type: string): string {
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

// Resolve all facets selected by the current init context.
function getSelectedFacets(ctx: ComposeContext): SelectedFacet[] {
  const catalog = ctx.config.bases as BasesCatalog;
  const selectedBaseKey = String(ctx.param.base ?? "");
  const selectedBase = catalog.features[selectedBaseKey];
  const selectedLibraryNames = new Set((ctx.param.libraries as string[] | undefined) ?? []);
  const selectedExtensionNames = new Set((ctx.param.extensions as string[] | undefined) ?? []);
  const selectedLocalExampleNames = new Set((ctx.param.localExamples as string[] | undefined) ?? []);

  const selected: SelectedFacet[] = [];

  for (const [name, entry] of Object.entries(catalog.globals.diamond?.required ?? {})) {
    selected.push({ name, entry, source: "diamond-required" });
  }

  for (const [name, entry] of Object.entries(catalog.globals.libraries?.required ?? {})) {
    selected.push({ name, entry, source: "library-required" });
  }

  for (const [name, entry] of Object.entries(selectedBase.required)) {
    selected.push({ name, entry, source: "base-required" });
  }

  for (const [name, entry] of Object.entries(catalog.globals.diamond?.optional ?? {})) {
    if (selectedLibraryNames.has(name)) {
      selected.push({ name, entry, source: "diamond-optional" });
    }
  }

  for (const [name, entry] of Object.entries(catalog.globals.libraries?.optional ?? {})) {
    if (selectedLibraryNames.has(name)) {
      selected.push({ name, entry, source: "library-optional" });
    }
  }

  for (const [name, entry] of Object.entries(selectedBase.optional)) {
    if (selectedExtensionNames.has(name)) {
      selected.push({ name, entry, source: "extension" });
    }
  }

  for (const [name, entry] of Object.entries(catalog.globals.examples?.optional ?? {})) {
    if (selectedLocalExampleNames.has(name)) {
      selected.push({ name, entry, source: "local-example" });
    }
  }

  return selected;
}

// Choose the scaffold target directory based on the selected facet category.
function targetDirectoryForFacet(root: string, facet: SelectedFacet): string {
  if (facet.source === "diamond-required" || facet.source === "diamond-optional") {
    return path.join(root, "src", "diamond");
  }

  if (facet.source === "library-required" || facet.source === "library-optional") {
    return path.join(root, "src", "libraries");
  }

  return path.join(root, "src", "facets");
}

// =====================
// Modules
// =====================

export const ScaffoldingModule = {
  // Scan selected facets for functions, exported selectors, and storage layouts.
  async scanSelectedFacets(ctx: ComposeContext): Promise<ComposeContext> {
    const selectedFacets = getSelectedFacets(ctx);
    const results: FacetScanResult[] = [];

    for (const facet of selectedFacets) {
      const resolvedPath = path.resolve(process.cwd(), facet.entry.path);
      const source = await fs.readFile(resolvedPath, "utf8");
      const contractMatch = source.match(/\bcontract\s+([A-Za-z_][A-Za-z0-9_]*)\b/);
      const functions = parseSolidityFunctions(source);
      const exportedSelectors = parseExportedSelectorNames(source);
      const exportedSet = new Set(exportedSelectors);
      const functionNames = new Set(functions.map((fn) => fn.name));
      const warnings: string[] = [];
      const storageScan = parseStorageLayouts(source);

      if (exportedSelectors.length === 0) {
        warnings.push("exportSelectors() was not found or did not export any this.<function>.selector entries.");
      }
      warnings.push(...storageScan.warnings);

      results.push({
        facetName: facet.name,
        source: facet.source,
        path: facet.entry.path,
        contractName: contractMatch?.[1] ?? null,
        functions,
        exportedSelectors,
        missingExports: functions.filter((fn) => !exportedSet.has(fn.name)).map((fn) => fn.signature),
        extraExports: exportedSelectors.filter((name) => !functionNames.has(name)),
        storageLayouts: storageScan.layouts,
        warnings,
      });
    }

    ctx.state.facetScan = {
      success: results.every((result) => result.missingExports.length === 0 && result.extraExports.length === 0),
      result: {
        facets: results,
        facetCount: results.length,
        selectorHashing: "not-computed",
        onchain: false,
      },
      error: null,
    };

    return ctx;
  },

  // Create the minimal Foundry project layout and copy selected facet sources.
  async scaffoldFoundryLayout(ctx: ComposeContext): Promise<ComposeContext> {
    const root = String(ctx.param.projectRoot ?? "");
    const selectedFacets = getSelectedFacets(ctx);

    await fs.mkdir(root, { recursive: true });
    await fs.mkdir(path.join(root, "src"), { recursive: true });
    await fs.mkdir(path.join(root, "src", "diamond"), { recursive: true });
    await fs.mkdir(path.join(root, "src", "libraries"), { recursive: true });
    await fs.mkdir(path.join(root, "src", "facets"), { recursive: true });
    await fs.mkdir(path.join(root, "script"), { recursive: true });
    await fs.mkdir(path.join(root, "test"), { recursive: true });

    const allSeeds: SeedFile[] = selectedFacets.map((facet) => ({
      source: path.resolve(process.cwd(), facet.entry.path),
      target: path.join(targetDirectoryForFacet(root, facet), path.basename(facet.entry.path)),
    }));
    const seedSources = allSeeds.map((x) => x.source);
    const closure = await resolveLocalSolidityImportClosure(seedSources);

    const sourceToTarget = new Map<string, string>();
    for (const seed of allSeeds) {
      sourceToTarget.set(path.resolve(seed.source), seed.target);
    }

    for (const file of closure) {
      const directTarget = sourceToTarget.get(path.resolve(file));
      if (directTarget) {
        await copyFileIfMissing(file, directTarget);
        continue;
      }

      // For transitive imports, co-locate with the importer directory in target by filename.
      // This keeps relative import structure stable for local imports.
      const parentSeed = allSeeds.find((seed) => file.startsWith(path.dirname(path.resolve(seed.source))));
      const baseTargetDir = parentSeed ? path.dirname(parentSeed.target) : path.join(root, "src");
      await copyFileIfMissing(file, path.join(baseTargetDir, path.basename(file)));
    }

    const foundryToml = `[profile.default]\nsrc = "src"\nout = "out"\nlibs = ["lib"]\n`;
    const remappings = "@perfect-abstractions/compose/=lib/compose/src/\n";
    const gitignore = "out/\ncache/\n";
    const readme = `# ${String(ctx.param.projectName)}\n\nGenerated by compose init (demo)\n`;

    await writeFileIfMissing(path.join(root, "foundry.toml"), foundryToml);
    await writeFileIfMissing(path.join(root, "remappings.txt"), remappings);
    await writeFileIfMissing(path.join(root, ".gitignore"), gitignore);
    await writeFileIfMissing(path.join(root, "README.md"), readme);

    return ctx;
  },

  // Write the generated compose.json into the resolved project root.
  async writeComposeConfig(ctx: ComposeContext): Promise<ComposeContext> {
    const root = String(ctx.param.projectRoot ?? "");
    const composeJson = ctx.config.composeJson;

    await fs.writeFile(path.join(root, "compose.json"), `${JSON.stringify(composeJson, null, 2)}\n`, "utf8");

    return ctx;
  },
};
