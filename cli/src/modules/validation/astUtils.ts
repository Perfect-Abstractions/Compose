export type AstNode = Record<string, unknown> & {
  id?: number;
  nodeType: string;
};

export function astNode(value: unknown): AstNode | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const candidate = value as Record<string, unknown>;
  return typeof candidate.nodeType === "string" ? candidate as AstNode : null;
}

export function childNodes(node: AstNode | null, key: string): AstNode[] {
  const value = node?.[key];
  return Array.isArray(value)
    ? value.map(astNode).filter((child): child is AstNode => child !== null)
    : [];
}

export function numberArray(value: unknown): number[] {
  return Array.isArray(value) ? value.filter((item): item is number => typeof item === "number") : [];
}

export function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}

type AstVisitor = (
  node: AstNode,
  ancestors: readonly AstNode[] | null,
  ownerContractId: number | null,
) => void;

/** Walks AST nodes in object and array order without collecting traversal context. */
export function walkAst(value: unknown, visitor: (node: AstNode) => void): void {
  walkAstInternal(value, (node) => visitor(node), null, null, false);
}

/** Walks AST nodes while passing the ancestors of each node (excluding that node). */
export function walkAstWithAncestors(
  value: unknown,
  visitor: (node: AstNode, ancestors: readonly AstNode[]) => void,
): void {
  walkAstInternal(value, (node, ancestors) => visitor(node, ancestors ?? []), [], null, false);
}

/** Walks AST nodes while tracking the current enclosing contract ID. */
export function walkAstWithContract(
  value: unknown,
  ownerContractId: number | null,
  visitor: (node: AstNode, ownerContractId: number | null) => void,
): void {
  walkAstInternal(
    value,
    (node, _ancestors, currentOwnerContractId) => visitor(node, currentOwnerContractId),
    null,
    ownerContractId,
    true,
  );
}

function walkAstInternal(
  value: unknown,
  visitor: AstVisitor,
  ancestors: readonly AstNode[] | null,
  ownerContractId: number | null,
  trackContractOwner: boolean,
): void {
  if (Array.isArray(value)) {
    for (const child of value) {
      walkAstInternal(child, visitor, ancestors, ownerContractId, trackContractOwner);
    }
    return;
  }

  const node = astNode(value);
  if (!node) return;

  const currentOwnerContractId = trackContractOwner &&
      node.nodeType === "ContractDefinition" && typeof node.id === "number"
    ? node.id
    : ownerContractId;
  visitor(node, ancestors, currentOwnerContractId);

  const childAncestors = ancestors === null ? null : [...ancestors, node];
  for (const child of Object.values(node)) {
    if (child && typeof child === "object") {
      walkAstInternal(child, visitor, childAncestors, currentOwnerContractId, trackContractOwner);
    }
  }
}
