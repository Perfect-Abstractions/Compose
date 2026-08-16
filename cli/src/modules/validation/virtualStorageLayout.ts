import { createHash } from "node:crypto";
import { SolidityAstSource } from "../../adapters/interface/IFrameworkAdapter";
import {
  VirtualStorageLayoutCollision,
  VirtualStorageLayoutRecord,
  VirtualStorageLayoutResult,
  VirtualStorageLayoutWarning,
} from "./types";

type AstNode = Record<string, unknown> & {
  id?: number;
  nodeType: string;
};

type ContainerKind = "mapping" | "dynamic-array" | "fixed-array";

type ChildLayout = {
  slot: number;
  structId: number;
  containerKind: ContainerKind;
};

type TypeAnalysis = {
  layout: string[];
  packBits: number[];
  slotGroups: number[][];
  children: ChildLayout[];
  warnings: string[];
  boundaryBefore: boolean;
  boundaryAfter: boolean;
};

type AstIndex = {
  nodesById: Map<number, AstNode>;
  contractsById: Map<number, AstNode>;
  ownerContractByNodeId: Map<number, number>;
  sourceByNodeId: Map<number, string>;
  initialValueByDeclarationId: Map<number, AstNode>;
};

type StorageRoot = {
  id: string;
  source: "erc8042" | "erc7201" | "slot-assignment" | "implicit-state";
  sourceName: string;
  contractName: string;
  structName: string | null;
  structId?: number;
  fields?: AstNode[];
};

type StorageScope = {
  completeContractIds: Set<number>;
  routineIds: Set<number>;
  referencedDeclarationIds: Set<number>;
  rootOwnerIds: Set<number>;
};

const CODE = {
  bool: "0x01",
  enum: "0x02",
  address: "0x03",
  externalFunction: "0x70",
  internalFunction: "0x71",
  bytes: "0x72",
  string: "0x73",
  mapping: "0xf1",
  dynamicArray: "0xf2",
  fixedArray: "0xf3",
  struct: "0xf4",
  unknown: "0xfe",
  end: "0xff",
} as const;

/** Builds compact virtual storage records and detects source-side collisions. */
export function buildVirtualStorageLayout(
  sources: SolidityAstSource[],
  facetNames: string[],
): VirtualStorageLayoutResult {
  const index = buildAstIndex(sources);
  const warnings: VirtualStorageLayoutWarning[] = [];
  const roots: StorageRoot[] = [];
  for (const facetName of facetNames) {
    const storageScope = traceFacetStorageScope(index, [facetName]);
    const facetRoots = [
      ...findExplicitRoots(index, storageScope),
      ...findImplicitRoots(index, [facetName]),
    ];
    roots.push(...facetRoots);

    if (facetRoots.length === 0) {
      const contract = [...index.contractsById.values()].find((node) => node.name === facetName);
      warnings.push({
        sourceName: contract ? sourceNameFor(contract, index) : facetName,
        message: `${facetName}: no storage pattern found; storage validation skipped for this facet.`,
      });
    }
  }
  const records: VirtualStorageLayoutRecord[] = [];
  const seenRoots = new Set<string>();

  for (const root of roots) {
    const rootKey = `${root.id}:${root.structId ?? root.contractName}`;
    if (seenRoots.has(rootKey)) continue;
    seenRoots.add(rootKey);

    const emitted = emitRecord({
      id: root.id,
      kind: "normal",
      fields: root.fields ?? structMembers(root.structId, index),
      root,
      index,
      seen: new Set(),
    });
    records.push(...emitted.records);
    warnings.push(...emitted.warnings);
  }

  return {
    records,
    warnings,
    collisions: findVirtualStorageLayoutCollisions(records),
  };
}

/** Finds incompatible records that share the same virtual storage id. */
export function findVirtualStorageLayoutCollisions(
  records: VirtualStorageLayoutRecord[],
): VirtualStorageLayoutCollision[] {
  const recordsById = new Map<string, VirtualStorageLayoutRecord[]>();
  for (const record of records) {
    const owners = recordsById.get(record.id) ?? [];
    owners.push(record);
    recordsById.set(record.id, owners);
  }

  const collisions: VirtualStorageLayoutCollision[] = [];
  for (const [id, owners] of recordsById) {
    if (owners.length <= 1) continue;

    const kinds = new Set(owners.map((record) => record.kind));
    if (kinds.size > 1) {
      collisions.push({ id, reason: "mixed normal and immutable records", records: owners });
      continue;
    }

    const compatible = kinds.has("immutable")
      ? owners.every((record) => immutableRecordsCompatible(owners[0], record))
      : arePrefixCompatible(owners.map((record) => record.layout));

    if (!compatible) {
      collisions.push({
        id,
        reason: kinds.has("immutable")
          ? "immutable layout changed"
          : "normal layout is not append-only compatible",
        records: owners,
      });
    }
  }

  return collisions;
}

function emitRecord(options: {
  id: string;
  kind: VirtualStorageLayoutRecord["kind"];
  fields: AstNode[];
  root: StorageRoot;
  index: AstIndex;
  seen: Set<string>;
}): { records: VirtualStorageLayoutRecord[]; warnings: VirtualStorageLayoutWarning[] } {
  const analysis = analyzeFields(options.fields, options.index);
  const record: VirtualStorageLayoutRecord = {
    id: options.id,
    kind: options.kind,
    codeWidth: 1,
    layout: analysis.layout,
    serializedLayout: ["0x01", ...analysis.layout],
    slots: analysis.slotGroups,
    source: options.root.source,
    sourceName: options.root.sourceName,
    contractName: options.root.contractName,
    structName: options.root.structName,
  };
  const records = [record];
  const warnings = analysis.warnings.map((message) => ({
    sourceName: options.root.sourceName,
    message,
  }));

  for (const child of analysis.children) {
    const childId = buildChildId(options.id, child.slot);
    const cycleKey = `${childId}:${child.structId}`;
    if (options.seen.has(cycleKey)) continue;

    const emitted = emitRecord({
      id: childId,
      kind: child.containerKind === "mapping" ? "normal" : "immutable",
      fields: structMembers(child.structId, options.index),
      root: options.root,
      index: options.index,
      seen: new Set([...options.seen, cycleKey]),
    });
    records.push(...emitted.records);
    warnings.push(...emitted.warnings);
  }

  return { records, warnings };
}

function analyzeFields(fields: AstNode[], index: AstIndex): TypeAnalysis {
  const layout: string[] = [];
  const slotGroups: number[][] = [];
  const children: ChildLayout[] = [];
  const warnings: string[] = [];
  let currentSlot: number[] = [];
  let usedBits = 0;

  const flushSlot = (): void => {
    if (currentSlot.length === 0) return;
    slotGroups.push(currentSlot);
    currentSlot = [];
    usedBits = 0;
  };

  for (const field of fields) {
    const analysis = analyzeType(astNode(field.typeName), index, {});
    layout.push(...analysis.layout);
    warnings.push(...analysis.warnings.map((warning) => `${stringValue(field.name)}: ${warning}`));

    const startsNewSlot =
      analysis.boundaryBefore ||
      analysis.slotGroups.length > 0 ||
      analysis.packBits.some((bits) => bits === 256);
    if (startsNewSlot) flushSlot();

    const fieldStartSlot = slotGroups.length;
    children.push(
      ...analysis.children.map((child) => ({
        ...child,
        slot: fieldStartSlot + child.slot,
      })),
    );

    if (analysis.slotGroups.length > 0) {
      slotGroups.push(...analysis.slotGroups.map((slot) => [...slot]));
      currentSlot = [];
      usedBits = 0;
      continue;
    }

    for (const bits of analysis.packBits) {
      if (bits === 256) {
        flushSlot();
        slotGroups.push([256]);
        continue;
      }
      if (usedBits + bits > 256) flushSlot();
      currentSlot.push(bits);
      usedBits += bits;
      if (usedBits === 256) flushSlot();
    }

    if (analysis.boundaryAfter) flushSlot();
  }

  flushSlot();
  return {
    layout,
    packBits: [],
    slotGroups,
    children,
    warnings,
    boundaryBefore: false,
    boundaryAfter: false,
  };
}

function analyzeType(
  type: AstNode | null,
  index: AstIndex,
  options: { insideContainer?: boolean; containerKind?: ContainerKind },
): TypeAnalysis {
  if (!type) return unknownType("missing AST type node");

  if (type.nodeType === "Mapping") {
    const key = scalarType(astNode(type.keyType), index);
    const value = analyzeType(astNode(type.valueType), index, {
      insideContainer: true,
      containerKind: "mapping",
    });
    return {
      layout: [CODE.mapping, key.code, ...ensureEnd(value.layout)],
      packBits: [],
      slotGroups: [[256]],
      children: value.children,
      warnings: [...key.warnings, ...value.warnings],
      boundaryBefore: false,
      boundaryAfter: false,
    };
  }

  if (type.nodeType === "ArrayTypeName") {
    const lengthNode = astNode(type.length);
    const fixedLength = lengthNode ? Number(lengthNode.value) : null;
    const containerKind: ContainerKind = fixedLength === null ? "dynamic-array" : "fixed-array";
    const element = analyzeType(astNode(type.baseType), index, {
      insideContainer: true,
      containerKind,
    });
    const prefix = fixedLength === null
      ? [CODE.dynamicArray]
      : [CODE.fixedArray, ...encodeFixedArrayLength(fixedLength)];

    if (fixedLength === null) {
      return {
        layout: [...prefix, ...ensureEnd(element.layout)],
        packBits: [],
        slotGroups: [[256]],
        children: element.children,
        warnings: element.warnings,
        boundaryBefore: false,
        boundaryAfter: false,
      };
    }

    return {
      layout: [...prefix, ...ensureEnd(element.layout)],
      packBits: [],
      slotGroups: repeatFixedArraySlots(fixedLength, element),
      children: element.children,
      warnings: element.warnings,
      boundaryBefore: true,
      boundaryAfter: true,
    };
  }

  const declaration = referencedDeclaration(type, index);
  if (declaration?.nodeType === "StructDefinition") {
    if (options.insideContainer) {
      return {
        layout: [CODE.end],
        packBits: [],
        slotGroups: [],
        children: [{
          slot: 0,
          structId: Number(declaration.id),
          containerKind: options.containerKind ?? "mapping",
        }],
        warnings: [],
        boundaryBefore: false,
        boundaryAfter: false,
      };
    }

    const nested = analyzeFields(childNodes(declaration, "members"), index);
    return {
      layout: [CODE.struct, ...nested.layout, CODE.end],
      packBits: [],
      slotGroups: nested.slotGroups,
      children: nested.children,
      warnings: nested.warnings,
      boundaryBefore: true,
      boundaryAfter: true,
    };
  }

  const scalar = scalarType(type, index);
  return {
    layout: [scalar.code],
    packBits: scalar.bits ? [scalar.bits] : [],
    slotGroups: scalar.wholeSlot ? [[256]] : [],
    children: [],
    warnings: scalar.warnings,
    boundaryBefore: false,
    boundaryAfter: false,
  };
}

function scalarType(
  type: AstNode | null,
  index: AstIndex,
): { code: string; bits?: number; wholeSlot?: boolean; warnings: string[] } {
  if (!type) return { code: CODE.unknown, wholeSlot: true, warnings: ["missing AST type node"] };

  const declaration = referencedDeclaration(type, index);
  if (declaration?.nodeType === "UserDefinedValueTypeDefinition") {
    return scalarType(astNode(declaration.underlyingType), index);
  }
  if (declaration?.nodeType === "EnumDefinition") {
    return { code: CODE.enum, bits: 8, warnings: [] };
  }
  if (declaration?.nodeType === "ContractDefinition") {
    return { code: CODE.address, bits: 160, warnings: [] };
  }

  if (type.nodeType === "FunctionTypeName") {
    if (type.visibility === "external") {
      return { code: CODE.externalFunction, bits: 192, warnings: [] };
    }
    return {
      code: CODE.internalFunction,
      wholeSlot: true,
      warnings: ["internal function storage type uses compiler-specific representation"],
    };
  }

  const name = stringValue(type.name);
  if (name === "bool") return { code: CODE.bool, bits: 8, warnings: [] };
  if (name === "address" || name === "address payable") {
    return { code: CODE.address, bits: 160, warnings: [] };
  }
  if (name === "bytes") return { code: CODE.bytes, wholeSlot: true, warnings: [] };
  if (name === "string") return { code: CODE.string, wholeSlot: true, warnings: [] };
  if (name === "byte") return { code: "0x50", bits: 8, warnings: [] };

  const uintBits = numericSuffix(name, "uint");
  if (uintBits !== null) return numericTypeCode(0x10, uintBits);
  const intBits = numericSuffix(name, "int");
  if (intBits !== null) return numericTypeCode(0x30, intBits);
  const bytesSize = numericSuffix(name, "bytes", false);
  if (bytesSize !== null && bytesSize >= 1 && bytesSize <= 32) {
    return { code: hexByte(0x50 + bytesSize - 1), bits: bytesSize * 8, warnings: [] };
  }

  return {
    code: CODE.unknown,
    wholeSlot: true,
    warnings: [`unsupported storage type: ${name || type.nodeType}`],
  };
}

function findExplicitRoots(index: AstIndex, scope: StorageScope): StorageRoot[] {
  const roots: StorageRoot[] = [];

  for (const contractId of scope.rootOwnerIds) {
    const contract = index.contractsById.get(contractId);
    if (!contract) continue;
    const contractName = stringValue(contract.name);
    const sourceName = sourceNameFor(contract, index);

    for (const node of childNodes(contract, "nodes")) {
      if (node.nodeType === "StructDefinition") {
        const annotation = storageAnnotation(node.documentation);
        const declarationId = typeof node.id === "number" ? node.id : null;
        const belongsToCompleteContract = scope.completeContractIds.has(contractId);
        const isReferenced = declarationId !== null && scope.referencedDeclarationIds.has(declarationId);
        if (annotation && declarationId !== null && (belongsToCompleteContract || isReferenced)) {
          roots.push({
            id: annotation.id,
            source: annotation.standard,
            sourceName,
            contractName,
            structName: stringValue(node.name),
            structId: node.id,
          });
        }
      }

      if (
        node.nodeType === "FunctionDefinition" &&
        typeof node.id === "number" &&
        scope.routineIds.has(node.id)
      ) {
        const root = slotAssignmentRoot(node, contract, index);
        if (root) roots.push(root);
      }
    }
  }

  return roots;
}

function findImplicitRoots(index: AstIndex, facetNames: string[]): StorageRoot[] {
  const roots: StorageRoot[] = [];

  for (const facetName of facetNames) {
    const contract = [...index.contractsById.values()].find((node) => node.name === facetName);
    if (!contract) continue;

    const fields: AstNode[] = [];
    const linearized = numberArray(contract.linearizedBaseContracts);
    const contractIds = linearized.length > 0
      ? [...linearized].reverse()
      : typeof contract.id === "number"
        ? [contract.id]
        : [];

    for (const contractId of contractIds) {
      const current = index.contractsById.get(contractId);
      if (!current) continue;
      fields.push(
        ...childNodes(current, "nodes").filter(
          (node) =>
            node.nodeType === "VariableDeclaration" &&
            node.stateVariable === true &&
            node.constant !== true &&
            node.mutability !== "immutable",
        ),
      );
    }

    if (fields.length > 0) {
      roots.push({
        id: "0x0",
        source: "implicit-state",
        sourceName: sourceNameFor(contract, index),
        contractName: facetName,
        structName: null,
        fields,
      });
    }
  }

  return roots;
}

function slotAssignmentRoot(
  fn: AstNode,
  contract: AstNode,
  index: AstIndex,
): StorageRoot | null {
  const returnParameter = childNodes(astNode(fn.returnParameters), "parameters").find(
    (parameter) => parameter.storageLocation === "storage",
  );
  if (!returnParameter) return null;

  const struct = referencedDeclaration(astNode(returnParameter.typeName), index);
  if (struct?.nodeType !== "StructDefinition" || typeof struct.id !== "number") return null;

  let namespace: string | null = null;
  walkAst(fn.body, (node) => {
    if (namespace || node.nodeType !== "InlineAssembly") return;
    const externalReferences = Array.isArray(node.externalReferences)
      ? node.externalReferences.filter(isRecord)
      : [];

    walkAst(node.AST, (yulNode) => {
      if (namespace || yulNode.nodeType !== "YulAssignment") return;
      const targets = childNodes(yulNode, "variableNames");
      const expectedTarget = `${stringValue(returnParameter.name)}.slot`;
      if (!targets.some((target) => target.name === expectedTarget)) return;

      const value = astNode(yulNode.value);
      const reference = externalReferences.find((candidate) => candidate.src === value?.src);
      const declarationId = typeof reference?.declaration === "number" ? reference.declaration : null;
      if (declarationId !== null) {
        namespace = resolveNamespaceDeclaration(declarationId, index, new Set());
      }
    });
  });

  return namespace
    ? {
        id: namespace,
        source: "slot-assignment",
        sourceName: sourceNameFor(contract, index),
        contractName: stringValue(contract.name),
        structName: stringValue(struct.name),
        structId: struct.id,
      }
    : null;
}

function resolveNamespaceDeclaration(
  declarationId: number,
  index: AstIndex,
  seen: Set<number>,
): string | null {
  if (seen.has(declarationId)) return null;
  seen.add(declarationId);

  const declaration = index.nodesById.get(declarationId);
  const expression = index.initialValueByDeclarationId.get(declarationId) ?? astNode(declaration?.value);
  return resolveNamespaceExpression(expression, index, seen);
}

function resolveNamespaceExpression(
  expression: AstNode | null,
  index: AstIndex,
  seen: Set<number>,
): string | null {
  if (!expression) return null;
  if (expression.nodeType === "Identifier" && typeof expression.referencedDeclaration === "number") {
    return resolveNamespaceDeclaration(expression.referencedDeclaration, index, seen);
  }
  if (expression.nodeType === "Literal") {
    return stringValue(expression.value) || stringValue(expression.hexValue);
  }
  if (expression.nodeType === "FunctionCall") {
    const fn = astNode(expression.expression);
    const args = childNodes(expression, "arguments");
    if (fn?.nodeType === "Identifier" && fn.name === "keccak256" && args.length === 1) {
      return resolveNamespaceExpression(args[0], index, seen);
    }
    if (expression.kind === "typeConversion" && args.length === 1) {
      return resolveNamespaceExpression(args[0], index, seen);
    }
  }
  return null;
}

function buildAstIndex(sources: SolidityAstSource[]): AstIndex {
  const nodesById = new Map<number, AstNode>();
  const contractsById = new Map<number, AstNode>();
  const ownerContractByNodeId = new Map<number, number>();
  const sourceByNodeId = new Map<number, string>();
  const initialValueByDeclarationId = new Map<number, AstNode>();

  for (const source of sources) {
    walkAstWithContract(source.ast, null, (node, ownerContractId) => {
      if (typeof node.id === "number") {
        nodesById.set(node.id, node);
        sourceByNodeId.set(node.id, source.sourceName);
        if (node.nodeType === "ContractDefinition") contractsById.set(node.id, node);
        if (ownerContractId !== null) ownerContractByNodeId.set(node.id, ownerContractId);
      }

      if (node.nodeType === "VariableDeclarationStatement") {
        const initialValue = astNode(node.initialValue);
        for (const declaration of childNodes(node, "declarations")) {
          if (initialValue && typeof declaration.id === "number") {
            initialValueByDeclarationId.set(declaration.id, initialValue);
          }
        }
      }
    });
  }

  return {
    nodesById,
    contractsById,
    ownerContractByNodeId,
    sourceByNodeId,
    initialValueByDeclarationId,
  };
}

function traceFacetStorageScope(index: AstIndex, facetNames: string[]): StorageScope {
  const completeContractIds = new Set<number>();
  const routineIds = new Set<number>();
  const referencedDeclarationIds = new Set<number>();
  const rootOwnerIds = new Set<number>();
  const storageExecutionOwnerIds = new Set<number>();
  const routineQueue: number[] = [];

  for (const contract of index.contractsById.values()) {
    if (!facetNames.includes(stringValue(contract.name))) continue;

    const lineage = numberArray(contract.linearizedBaseContracts);
    const lineageIds = lineage.length > 0
      ? lineage
      : typeof contract.id === "number"
        ? [contract.id]
        : [];
    lineageIds.forEach((contractId) => {
      completeContractIds.add(contractId);
      rootOwnerIds.add(contractId);
      storageExecutionOwnerIds.add(contractId);
    });

    for (const routineId of facetRuntimeEntryIds(lineageIds, index)) {
      routineQueue.push(routineId);
    }
  }

  while (routineQueue.length > 0) {
    const routineId = routineQueue.shift();
    if (routineId === undefined || routineIds.has(routineId)) continue;

    const routine = index.nodesById.get(routineId);
    if (!routine || !isRoutine(routine)) continue;
    routineIds.add(routineId);

    const routineOwnerId = index.ownerContractByNodeId.get(routineId);
    if (routineOwnerId !== undefined) rootOwnerIds.add(routineOwnerId);

    walkAst(routine, (node) => {
      const declarationId = typeof node.referencedDeclaration === "number"
        ? node.referencedDeclaration
        : null;
      if (declarationId !== null && declarationId >= 0) {
        referencedDeclarationIds.add(declarationId);
        const declarationOwnerId = index.ownerContractByNodeId.get(declarationId);
        if (declarationOwnerId !== undefined) rootOwnerIds.add(declarationOwnerId);
      }

      if (node.nodeType === "ModifierInvocation") {
        enqueueModifier(node, index, routineQueue);
      }
      if (node.nodeType === "FunctionCall") {
        enqueueStorageContextCall(
          node,
          routineOwnerId,
          completeContractIds,
          storageExecutionOwnerIds,
          index,
          routineQueue,
        );
      }
    });
  }

  return {
    completeContractIds,
    routineIds,
    referencedDeclarationIds,
    rootOwnerIds,
  };
}

function facetRuntimeEntryIds(contractIds: number[], index: AstIndex): number[] {
  const selectedIds: number[] = [];
  const claimedSignatures = new Set<string>();

  for (const contractId of contractIds) {
    const contract = index.contractsById.get(contractId);
    if (!contract) continue;

    for (const node of childNodes(contract, "nodes")) {
      if (node.nodeType !== "FunctionDefinition" || typeof node.id !== "number") continue;
      if (!isRuntimeEntry(node)) continue;

      const signature = routineDispatchKey(node);
      if (claimedSignatures.has(signature)) continue;
      claimedSignatures.add(signature);
      selectedIds.push(node.id);
    }
  }

  return selectedIds;
}

function enqueueModifier(node: AstNode, index: AstIndex, queue: number[]): void {
  const modifierName = astNode(node.modifierName);
  const declarationId = typeof modifierName?.referencedDeclaration === "number"
    ? modifierName.referencedDeclaration
    : null;
  if (declarationId === null) return;

  const declaration = index.nodesById.get(declarationId);
  if (declaration?.nodeType === "ModifierDefinition") queue.push(declarationId);
}

function enqueueStorageContextCall(
  call: AstNode,
  callerOwnerId: number | undefined,
  selectedContractIds: Set<number>,
  storageExecutionOwnerIds: Set<number>,
  index: AstIndex,
  queue: number[],
): void {
  const expression = unwrapCallExpression(astNode(call.expression));
  const declarationId = typeof expression?.referencedDeclaration === "number"
    ? expression.referencedDeclaration
    : null;
  if (declarationId === null || declarationId < 0) return;

  const declaration = index.nodesById.get(declarationId);
  if (declaration?.nodeType !== "FunctionDefinition") return;

  const calleeOwnerId = index.ownerContractByNodeId.get(declarationId);
  if (calleeOwnerId === undefined) {
    queue.push(declarationId);
    return;
  }

  const calleeOwner = index.contractsById.get(calleeOwnerId);
  const sharesStorageContext =
    calleeOwnerId === callerOwnerId ||
    selectedContractIds.has(calleeOwnerId) ||
    storageExecutionOwnerIds.has(calleeOwnerId) ||
    calleeOwner?.contractKind === "library";
  if (sharesStorageContext) {
    storageExecutionOwnerIds.add(calleeOwnerId);
    queue.push(declarationId);
  }
}

function unwrapCallExpression(node: AstNode | null): AstNode | null {
  let current = node;
  while (current?.nodeType === "FunctionCallOptions") {
    current = astNode(current.expression);
  }
  return current;
}

function isRuntimeEntry(node: AstNode): boolean {
  return node.kind === "fallback" ||
    node.kind === "receive" ||
    node.visibility === "public" ||
    node.visibility === "external";
}

function isRoutine(node: AstNode): boolean {
  return node.nodeType === "FunctionDefinition" || node.nodeType === "ModifierDefinition";
}

function routineDispatchKey(node: AstNode): string {
  if (typeof node.functionSelector === "string") return node.functionSelector;
  if (node.kind === "fallback" || node.kind === "receive") return stringValue(node.kind);
  const parameters = childNodes(astNode(node.parameters), "parameters")
    .map((parameter) => {
      const descriptions = astNode(parameter.typeDescriptions);
      return stringValue(descriptions?.typeIdentifier) || stringValue(descriptions?.typeString);
    });
  return `${stringValue(node.name)}(${parameters.join(",")})`;
}

function repeatFixedArraySlots(length: number, element: TypeAnalysis): number[][] {
  if (!Number.isInteger(length) || length <= 0) return [];
  if (element.slotGroups.length > 0) {
    return Array.from({ length }, () => element.slotGroups.map((group) => [...group])).flat();
  }
  if (element.packBits.length === 0) return [[256]];

  const groups: number[][] = [];
  let current: number[] = [];
  let usedBits = 0;
  const flush = (): void => {
    if (current.length === 0) return;
    groups.push(current);
    current = [];
    usedBits = 0;
  };

  for (let index = 0; index < length; index++) {
    for (const bits of element.packBits) {
      if (bits === 256) {
        flush();
        groups.push([256]);
      } else {
        if (usedBits + bits > 256) flush();
        current.push(bits);
        usedBits += bits;
        if (usedBits === 256) flush();
      }
    }
  }
  flush();
  return groups;
}

function encodeFixedArrayLength(length: number): string[] {
  if (!Number.isInteger(length) || length <= 0) return ["0x00"];
  let hex = length.toString(16);
  if (hex.length % 2 === 1) hex = `0${hex}`;
  const bytes = hex.match(/.{2}/g) ?? ["00"];
  return [hexByte(bytes.length), ...bytes.map((byte) => `0x${byte}`)];
}

function storageAnnotation(value: unknown): {
  standard: "erc8042" | "erc7201";
  id: string;
} | null {
  const documentation = typeof value === "string"
    ? value
    : isRecord(value) && typeof value.text === "string"
      ? value.text
      : "";
  const marker = "@custom:storage-location";
  const markerIndex = documentation.indexOf(marker);
  if (markerIndex === -1) return null;
  const token = documentation.slice(markerIndex + marker.length).trim().split(/\s+/)[0] ?? "";
  const separator = token.indexOf(":");
  const standard = token.slice(0, separator);
  const id = token.slice(separator + 1);
  return (standard === "erc8042" || standard === "erc7201") && id
    ? { standard, id }
    : null;
}

function numericSuffix(value: string, prefix: string, defaultTo256 = true): number | null {
  if (value === prefix && defaultTo256) return 256;
  if (!value.startsWith(prefix)) return null;
  const suffix = value.slice(prefix.length);
  if (!suffix || [...suffix].some((character) => character < "0" || character > "9")) return null;
  return Number(suffix);
}

function numericTypeCode(
  base: number,
  bits: number,
): { code: string; bits?: number; wholeSlot?: boolean; warnings: string[] } {
  if (bits < 8 || bits > 256 || bits % 8 !== 0) {
    return { code: CODE.unknown, wholeSlot: true, warnings: [`invalid numeric width: ${bits}`] };
  }
  return { code: hexByte(base + bits / 8 - 1), bits, warnings: [] };
}

function unknownType(message: string): TypeAnalysis {
  return {
    layout: [CODE.unknown],
    packBits: [],
    slotGroups: [[256]],
    children: [],
    warnings: [message],
    boundaryBefore: false,
    boundaryAfter: false,
  };
}

function referencedDeclaration(type: AstNode | null, index: AstIndex): AstNode | null {
  const declarationId = typeof type?.referencedDeclaration === "number"
    ? type.referencedDeclaration
    : null;
  return declarationId === null ? null : index.nodesById.get(declarationId) ?? null;
}

function structMembers(structId: number | undefined, index: AstIndex): AstNode[] {
  if (structId === undefined) return [];
  return childNodes(index.nodesById.get(structId) ?? null, "members");
}

function sourceNameFor(node: AstNode, index: AstIndex): string {
  return typeof node.id === "number" ? index.sourceByNodeId.get(node.id) ?? "" : "";
}

function buildChildId(parentId: string, slot: number): string {
  const pattern = `keccak(${parentId} . ${slot})`;
  const digest = createHash("sha256").update(pattern).digest("hex");
  return `0x${digest} // ${pattern}`;
}

function ensureEnd(layout: string[]): string[] {
  return layout.at(-1) === CODE.end ? layout : [...layout, CODE.end];
}

function arePrefixCompatible(layouts: string[][]): boolean {
  const sorted = [...layouts].sort((left, right) => left.length - right.length);
  return sorted.every((layout, index) =>
    index === 0 || sorted[index - 1].every(
      (token, tokenIndex) => tokensCompatible(token, layout[tokenIndex]),
    ),
  );
}

function immutableRecordsCompatible(
  left: VirtualStorageLayoutRecord,
  right: VirtualStorageLayoutRecord,
): boolean {
  if (left.layout.length !== right.layout.length) return false;
  if (!left.layout.every((token, index) => tokensCompatible(token, right.layout[index]))) {
    return false;
  }

  const hasUncertainType = [...left.layout, ...right.layout].some(isUncertainCode);
  return hasUncertainType || (
    left.slots.length === right.slots.length &&
    left.slots.every((slot, index) => arraysEqual(slot, right.slots[index]))
  );
}

function tokensCompatible(left: string, right: string | undefined): boolean {
  return right !== undefined && (
    left === right || isUncertainCode(left) || isUncertainCode(right)
  );
}

function isUncertainCode(code: string): boolean {
  return code === CODE.internalFunction || code === CODE.unknown;
}

function arraysEqual<T>(left: T[], right: T[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function walkAst(value: unknown, visitor: (node: AstNode) => void): void {
  if (Array.isArray(value)) {
    for (const child of value) walkAst(child, visitor);
    return;
  }
  const node = astNode(value);
  if (!node) return;
  visitor(node);
  for (const child of Object.values(node)) {
    if (child && typeof child === "object") walkAst(child, visitor);
  }
}

function walkAstWithContract(
  value: unknown,
  ownerContractId: number | null,
  visitor: (node: AstNode, ownerContractId: number | null) => void,
): void {
  if (Array.isArray(value)) {
    for (const child of value) walkAstWithContract(child, ownerContractId, visitor);
    return;
  }
  const node = astNode(value);
  if (!node) return;
  const nextOwner = node.nodeType === "ContractDefinition" && typeof node.id === "number"
    ? node.id
    : ownerContractId;
  visitor(node, nextOwner);
  for (const child of Object.values(node)) {
    if (child && typeof child === "object") walkAstWithContract(child, nextOwner, visitor);
  }
}

function childNodes(node: AstNode | null, key: string): AstNode[] {
  const value = node?.[key];
  return Array.isArray(value)
    ? value.map(astNode).filter((child): child is AstNode => child !== null)
    : [];
}

function astNode(value: unknown): AstNode | null {
  return isRecord(value) && typeof value.nodeType === "string" ? value as AstNode : null;
}

function numberArray(value: unknown): number[] {
  return Array.isArray(value) ? value.filter((item): item is number => typeof item === "number") : [];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function hexByte(value: number): string {
  return `0x${value.toString(16).padStart(2, "0")}`;
}
