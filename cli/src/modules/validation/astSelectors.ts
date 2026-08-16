import { SolidityAstSource } from "../../adapters/interface/IFrameworkAdapter";
import { FacetScanResult, FunctionInfo } from "./types";

type AstNode = Record<string, unknown> & {
  id?: number;
  nodeType: string;
};

type AstIndex = {
  nodesById: Map<number, AstNode>;
  contractsById: Map<number, AstNode>;
  sourceByContractId: Map<number, string>;
};

/** Extracts selector declarations for named facets from compiler AST output. */
export function scanFacetSelectorsFromAst(
  sources: SolidityAstSource[],
  facetNames: string[],
): FacetScanResult[] {
  const index = buildAstIndex(sources);

  return facetNames.map((facetName) => {
    const matches = [...index.contractsById.values()].filter(
      (contract) => contract.name === facetName,
    );

    if (matches.length !== 1) {
      throw new Error(
        matches.length === 0
          ? `Facet contract not found in Solidity AST: ${facetName}`
          : `Facet contract is ambiguous in Solidity AST: ${facetName}`,
      );
    }

    return scanContract(matches[0], index);
  });
}

function scanContract(contract: AstNode, index: AstIndex): FacetScanResult {
  const linearizedContractIds = numberArray(contract.linearizedBaseContracts);
  const contractIds = linearizedContractIds.length > 0
    ? linearizedContractIds
    : typeof contract.id === "number"
      ? [contract.id]
      : [];
  const functionsBySignature = new Map<string, { info: FunctionInfo; declarationId: number }>();
  const functionSignaturesById = new Map<number, string>();
  let exportFunction: AstNode | null = null;

  for (const contractId of contractIds) {
    const current = index.contractsById.get(contractId);
    if (!current) {
      continue;
    }

    for (const node of childNodes(current, "nodes")) {
      if (node.nodeType !== "FunctionDefinition" || node.kind !== "function") {
        continue;
      }

      if (node.name === "exportSelectors" && exportFunction === null) {
        exportFunction = node;
        continue;
      }

      if (node.visibility !== "public" && node.visibility !== "external") {
        continue;
      }

      const signature = functionSignature(node, index);
      if (typeof node.id === "number") {
        functionSignaturesById.set(node.id, signature);
      }
      if (!functionsBySignature.has(signature) && typeof node.id === "number") {
        functionsBySignature.set(signature, {
          declarationId: node.id,
          info: {
            name: stringValue(node.name),
            signature,
            visibility: node.visibility,
          },
        });
      }
    }
  }

  const functions = [...functionsBySignature.values()].map(({ info }) => info);
  const exportedSelectors = exportFunction
    ? collectExportedSignatures(exportFunction, functionSignaturesById)
    : [];
  const functionSignatures = new Set(functions.map((fn) => fn.signature));
  const exportedSet = new Set(exportedSelectors);
  const facetName = stringValue(contract.name);
  const sourceName = typeof contract.id === "number"
    ? index.sourceByContractId.get(contract.id) ?? ""
    : "";

  return {
    facetName,
    path: sourceName,
    functions,
    exportedSelectors,
    hasExportSelectorsFunction: exportFunction !== null,
    missingExports: functions
      .filter((fn) => !exportedSet.has(fn.signature))
      .map((fn) => fn.signature),
    extraExports: exportedSelectors.filter((signature) => !functionSignatures.has(signature)),
    storageLayouts: [],
    warnings: [],
  };
}

function collectExportedSignatures(
  exportFunction: AstNode,
  functionSignaturesById: Map<number, string>,
): string[] {
  const signatures = new Set<string>();

  walkAst(exportFunction.body, (node, ancestors) => {
    if (node.nodeType === "MemberAccess" && node.memberName === "selector") {
      const expression = astNode(node.expression);
      const declarationId = expression && typeof expression.referencedDeclaration === "number"
        ? expression.referencedDeclaration
        : null;
      const signature = declarationId === null
        ? null
        : functionSignaturesById.get(declarationId);
      if (signature) {
        signatures.add(signature);
      }
      return;
    }

    if (
      node.nodeType === "Literal" &&
      node.kind === "string" &&
      ancestors.some(isKeccak256Call) &&
      ancestors.some(isBytes4Conversion)
    ) {
      const signature = stringValue(node.value).replace(/\s+/g, "");
      if (signature.includes("(") && signature.endsWith(")")) {
        signatures.add(signature);
      }
    }
  });

  return [...signatures];
}

function functionSignature(node: AstNode, index: AstIndex): string {
  const parameters = astNode(node.parameters);
  const parameterTypes = childNodes(parameters, "parameters")
    .map((parameter) => canonicalAbiType(astNode(parameter.typeName), index));
  return `${stringValue(node.name)}(${parameterTypes.join(",")})`;
}

function canonicalAbiType(type: AstNode | null, index: AstIndex): string {
  if (!type) {
    return "unknown";
  }

  if (type.nodeType === "ElementaryTypeName") {
    const name = stringValue(type.name);
    if (name === "uint") return "uint256";
    if (name === "int") return "int256";
    if (name === "address payable") return "address";
    return name;
  }

  if (type.nodeType === "ArrayTypeName") {
    const baseType = canonicalAbiType(astNode(type.baseType), index);
    const length = astNode(type.length);
    return `${baseType}[${length ? stringValue(length.value) : ""}]`;
  }

  if (type.nodeType === "UserDefinedTypeName") {
    const declarationId = typeof type.referencedDeclaration === "number"
      ? type.referencedDeclaration
      : null;
    const declaration = declarationId === null ? null : index.nodesById.get(declarationId);

    if (declaration?.nodeType === "StructDefinition") {
      return `(${childNodes(declaration, "members")
        .map((member) => canonicalAbiType(astNode(member.typeName), index))
        .join(",")})`;
    }
    if (declaration?.nodeType === "EnumDefinition") return "uint8";
    if (declaration?.nodeType === "ContractDefinition") return "address";
    if (declaration?.nodeType === "UserDefinedValueTypeDefinition") {
      return canonicalAbiType(astNode(declaration.underlyingType), index);
    }
  }

  if (type.nodeType === "FunctionTypeName") {
    return "function";
  }

  const descriptions = astNode(type.typeDescriptions);
  return stringValue(descriptions?.typeString).replace(/\s+(memory|storage|calldata)\b/g, "");
}

function buildAstIndex(sources: SolidityAstSource[]): AstIndex {
  const nodesById = new Map<number, AstNode>();
  const contractsById = new Map<number, AstNode>();
  const sourceByContractId = new Map<number, string>();

  for (const source of sources) {
    walkAst(source.ast, (node) => {
      if (typeof node.id === "number") {
        nodesById.set(node.id, node);
        if (node.nodeType === "ContractDefinition") {
          contractsById.set(node.id, node);
          sourceByContractId.set(node.id, source.sourceName);
        }
      }
    });
  }

  return { nodesById, contractsById, sourceByContractId };
}

function walkAst(
  value: unknown,
  visitor: (node: AstNode, ancestors: AstNode[]) => void,
  ancestors: AstNode[] = [],
): void {
  if (Array.isArray(value)) {
    for (const child of value) walkAst(child, visitor, ancestors);
    return;
  }

  const node = astNode(value);
  if (!node) return;

  visitor(node, ancestors);
  for (const child of Object.values(node)) {
    if (child && typeof child === "object") {
      walkAst(child, visitor, [...ancestors, node]);
    }
  }
}

function isKeccak256Call(node: AstNode): boolean {
  if (node.nodeType !== "FunctionCall") return false;
  const expression = astNode(node.expression);
  return expression?.nodeType === "Identifier" && expression.name === "keccak256";
}

function isBytes4Conversion(node: AstNode): boolean {
  if (node.nodeType !== "FunctionCall" || node.kind !== "typeConversion") return false;
  const expression = astNode(node.expression);
  const typeName = expression && astNode(expression.typeName);
  return typeName?.nodeType === "ElementaryTypeName" && typeName.name === "bytes4";
}

function childNodes(node: AstNode | null, key: string): AstNode[] {
  const value = node?.[key];
  return Array.isArray(value)
    ? value.map(astNode).filter((child): child is AstNode => child !== null)
    : [];
}

function astNode(value: unknown): AstNode | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const candidate = value as Record<string, unknown>;
  return typeof candidate.nodeType === "string" ? candidate as AstNode : null;
}

function numberArray(value: unknown): number[] {
  return Array.isArray(value) ? value.filter((item): item is number => typeof item === "number") : [];
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}
