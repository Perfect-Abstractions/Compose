import { SoliditySourceUnitAst } from "../../../src/adapters/interface/IFrameworkAdapter";

/** Sorts AST object keys recursively so expected fixtures are stable and reviewable. */
export function canonicalizeAst(ast: SoliditySourceUnitAst): unknown {
  return canonicalizeValue(ast);
}

function canonicalizeValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(canonicalizeValue);
  }

  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, child]) => [key, canonicalizeValue(child)]),
    );
  }

  return value;
}
