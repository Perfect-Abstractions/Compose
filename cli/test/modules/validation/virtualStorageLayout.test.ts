import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { SolidityAstSource } from "../../../src/adapters/interface/IFrameworkAdapter";
import {
  FacetReference,
  VirtualStorageLayoutRecord,
} from "../../../src/modules/validation/types";
import {
  buildScopedVirtualStorageLayout,
  buildVirtualStorageLayout,
  deriveStorageRootId,
  findUnsupportedVirtualStorageLayouts,
  findVirtualStorageLayoutCollisions,
  hashVirtualPath,
} from "../../../src/modules/validation/virtualStorageLayout";

function independentDiamondAstSource(): SolidityAstSource {
  const contract = (id: number, name: string, typeName: string) => ({
    contractKind: "contract",
    id,
    linearizedBaseContracts: [id],
    name,
    nodeType: "ContractDefinition",
    nodes: [{
      constant: false,
      id: id + 1,
      mutability: "mutable",
      name: "value",
      nodeType: "VariableDeclaration",
      stateVariable: true,
      typeName: {
        id: id + 2,
        name: typeName,
        nodeType: "ElementaryTypeName",
      },
    }],
  });

  return {
    sourceName: "src/IndependentFacets.sol",
    ast: {
      id: 5000,
      nodeType: "SourceUnit",
      src: "0:0:0",
      nodes: [
        contract(100, "AlphaFacet", "uint256"),
        contract(200, "BetaFacet", "address"),
      ],
    },
  };
}

function duplicateContractAstSources(): SolidityAstSource[] {
  const source = (sourceName: string, id: number, typeName: string): SolidityAstSource => ({
    sourceName,
    ast: {
      id: id + 1000,
      nodeType: "SourceUnit",
      src: "0:0:0",
      nodes: [{
        contractKind: "contract",
        id,
        linearizedBaseContracts: [id],
        name: "Foo",
        nodeType: "ContractDefinition",
        nodes: [{
          constant: false,
          id: id + 1,
          mutability: "mutable",
          name: "value",
          nodeType: "VariableDeclaration",
          stateVariable: true,
          typeName: {
            id: id + 2,
            name: typeName,
            nodeType: "ElementaryTypeName",
          },
        }],
      }],
    },
  });

  return [
    source("src/a/Foo.sol", 6000, "uint256"),
    source("src/b/Foo.sol", 7000, "address"),
  ];
}

function nestedVirtualPathAstSource(
  standard: "erc8042" | "erc7201" = "erc8042",
): SolidityAstSource {
  const uintField = (id: number, name: string) => ({
    id,
    name,
    nodeType: "VariableDeclaration",
    typeName: { id: id + 1000, name: "uint256", nodeType: "ElementaryTypeName" },
  });
  const deepStruct = {
    id: 300,
    members: [uintField(301, "value")],
    name: "DeepStorage",
    nodeType: "StructDefinition",
  };
  const childStruct = {
    id: 200,
    members: [
      uintField(201, "a"),
      uintField(202, "b"),
      uintField(203, "c"),
      {
        id: 204,
        name: "items",
        nodeType: "VariableDeclaration",
        typeName: {
          baseType: {
            id: 1204,
            name: "DeepStorage",
            nodeType: "UserDefinedTypeName",
            referencedDeclaration: 300,
          },
          id: 2204,
          length: null,
          nodeType: "ArrayTypeName",
        },
      },
    ],
    name: "ChildStorage",
    nodeType: "StructDefinition",
  };
  const rootStruct = {
    documentation: { text: `@custom:storage-location ${standard}:erc20` },
    id: 100,
    members: [
      uintField(101, "a"),
      uintField(102, "b"),
      uintField(103, "c"),
      uintField(104, "d"),
      uintField(105, "e"),
      {
        id: 106,
        name: "children",
        nodeType: "VariableDeclaration",
        typeName: {
          id: 1106,
          keyType: { id: 2106, name: "uint256", nodeType: "ElementaryTypeName" },
          nodeType: "Mapping",
          valueType: {
            id: 3106,
            name: "ChildStorage",
            nodeType: "UserDefinedTypeName",
            referencedDeclaration: 200,
          },
        },
      },
    ],
    name: "RootStorage",
    nodeType: "StructDefinition",
  };

  return {
    sourceName: "src/PathFacet.sol",
    ast: {
      id: 9000,
      nodeType: "SourceUnit",
      src: "0:0:0",
      nodes: [{
        contractKind: "contract",
        id: 1,
        linearizedBaseContracts: [1],
        name: "PathFacet",
        nodeType: "ContractDefinition",
        nodes: [rootStruct, childStruct, deepStruct],
      }],
    },
  };
}

function fixedArrayStructAstSource(): SolidityAstSource {
  const elementaryField = (id: number, name: string, typeName: string) => ({
    id,
    name,
    nodeType: "VariableDeclaration",
    typeName: { id: id + 1000, name: typeName, nodeType: "ElementaryTypeName" },
  });
  const elementStruct = {
    id: 200,
    members: [
      elementaryField(201, "small", "uint8"),
      elementaryField(202, "wide", "uint96"),
    ],
    name: "ElementStorage",
    nodeType: "StructDefinition",
  };
  const tailStruct = {
    id: 300,
    members: [elementaryField(301, "value", "uint256")],
    name: "TailStorage",
    nodeType: "StructDefinition",
  };
  const rootStruct = {
    documentation: { text: "@custom:storage-location erc8042:fixed.struct" },
    id: 100,
    members: [
      {
        id: 101,
        name: "items",
        nodeType: "VariableDeclaration",
        typeName: {
          baseType: {
            id: 1101,
            name: "ElementStorage",
            nodeType: "UserDefinedTypeName",
            referencedDeclaration: 200,
          },
          id: 2101,
          length: { id: 3101, nodeType: "Literal", value: "5" },
          nodeType: "ArrayTypeName",
        },
      },
      {
        id: 102,
        name: "tails",
        nodeType: "VariableDeclaration",
        typeName: {
          id: 1102,
          keyType: { id: 2102, name: "uint256", nodeType: "ElementaryTypeName" },
          nodeType: "Mapping",
          valueType: {
            id: 3102,
            name: "TailStorage",
            nodeType: "UserDefinedTypeName",
            referencedDeclaration: 300,
          },
        },
      },
    ],
    name: "RootStorage",
    nodeType: "StructDefinition",
  };

  return {
    sourceName: "src/FixedArrayFacet.sol",
    ast: {
      id: 9000,
      nodeType: "SourceUnit",
      src: "0:0:0",
      nodes: [{
        contractKind: "contract",
        id: 1,
        linearizedBaseContracts: [1],
        name: "FixedArrayFacet",
        nodeType: "ContractDefinition",
        nodes: [rootStruct, elementStruct, tailStruct],
      }],
    },
  };
}

const normalAstPath = resolve(
  __dirname,
  "fixtures/normal/expected/hardhat.ast.json",
);

function normalAstSource(): SolidityAstSource {
  return {
    sourceName: "project/contracts/Normal.sol",
    ast: JSON.parse(readFileSync(normalAstPath, "utf8")),
  };
}

function libraryReachabilityAstSource(): SolidityAstSource {
  const annotatedStruct = (id: number, name: string, namespace: string) => ({
    documentation: { text: `@custom:storage-location erc8042:${namespace}` },
    id,
    members: [{
      id: id + 100,
      name: "value",
      nodeType: "VariableDeclaration",
      typeName: { id: id + 200, name: "uint256", nodeType: "ElementaryTypeName" },
    }],
    name,
    nodeType: "StructDefinition",
  });

  return {
    sourceName: "src/ReachableFacet.sol",
    ast: {
      id: 1000,
      nodeType: "SourceUnit",
      src: "0:0:0",
      nodes: [
        {
          contractKind: "contract",
          id: 1,
          linearizedBaseContracts: [1],
          name: "ReachableFacet",
          nodeType: "ContractDefinition",
          nodes: [{
            body: {
              id: 3,
              nodeType: "Block",
              statements: [{
                expression: {
                  expression: {
                    id: 5,
                    memberName: "touchUsedStorage",
                    nodeType: "MemberAccess",
                    referencedDeclaration: 12,
                  },
                  id: 4,
                  nodeType: "FunctionCall",
                },
                id: 6,
                nodeType: "ExpressionStatement",
              }],
            },
            id: 2,
            kind: "function",
            name: "run",
            nodeType: "FunctionDefinition",
            parameters: { id: 7, nodeType: "ParameterList", parameters: [] },
            visibility: "external",
          }],
        },
        {
          contractKind: "library",
          id: 10,
          linearizedBaseContracts: [10],
          name: "StorageLibrary",
          nodeType: "ContractDefinition",
          nodes: [
            annotatedStruct(20, "UsedStorage", "used.storage"),
            annotatedStruct(21, "UnusedStorage", "unused.storage"),
            {
              body: {
                id: 13,
                nodeType: "Block",
                statements: [{
                  declarations: [{
                    id: 14,
                    name: "storageValue",
                    nodeType: "VariableDeclaration",
                    typeName: {
                      id: 15,
                      name: "UsedStorage",
                      nodeType: "UserDefinedTypeName",
                      referencedDeclaration: 20,
                    },
                  }],
                  id: 16,
                  nodeType: "VariableDeclarationStatement",
                }],
              },
              id: 12,
              kind: "function",
              name: "touchUsedStorage",
              nodeType: "FunctionDefinition",
              parameters: { id: 17, nodeType: "ParameterList", parameters: [] },
              visibility: "internal",
            },
          ],
        },
      ],
    },
  };
}

function record(layout: string[]): VirtualStorageLayoutRecord {
  return {
    id: hashVirtualPath("shared.storage"),
    virtualPath: "shared.storage",
    kind: "normal",
    codeWidth: 1,
    layout,
    serializedLayout: ["0x01", ...layout],
    slots: [[256]],
    source: "slot-assignment",
    sourceName: "src/Facet.sol",
    contractName: "Facet",
    structName: "FacetStorage",
  };
}

function facet(contractName: string, sourcePath: string): FacetReference {
  return { contractName, sourcePath };
}

describe("virtual storage layout", () => {
  it("derives root and nested IDs from canonical readable paths", () => {
    expect(hashVirtualPath("erc20")).toBe(
      "0x5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9",
    );
    expect(hashVirtualPath("erc20.5")).toBe(
      "0xd9017c3d0d4c93e47f2713117035682e1f0ea26c03fe341b3b184c078338d0d9",
    );
    expect(hashVirtualPath("erc20.5.3")).toBe(
      "0x15a679fb4dca6bd150612cf0d9a19d650ed3bb8b67f60e0808e5033d49d74c5a",
    );
  });

  it("derives ERC-8042 and ERC-7201 namespace roots with their canonical formulas", () => {
    expect(deriveStorageRootId("example.main", "erc8042")).toBe(
      hashVirtualPath("example.main"),
    );
    expect(deriveStorageRootId("example.main", "erc7201")).toBe(
      "0x183a6125c38840424c4a85fa12bab2ab606c4b6d0e7cc73c0c06ba5300eab500",
    );
    expect(deriveStorageRootId(
      "0x183a6125c38840424c4a85fa12bab2ab606c4b6d0e7cc73c0c06ba5300eab500",
      "slot-assignment",
    )).toBe("0x183a6125c38840424c4a85fa12bab2ab606c4b6d0e7cc73c0c06ba5300eab500");

    const result = buildVirtualStorageLayout(
      [nestedVirtualPathAstSource("erc7201")],
      [facet("PathFacet", "src/PathFacet.sol")],
    );
    expect(result.records[0].id).toBe(deriveStorageRootId("erc20", "erc7201"));
    expect(result.records[0].source).toBe("erc7201");
  });

  it("uses source path to scope storage for duplicate contract names", () => {
    const sources = duplicateContractAstSources();
    const fooA = facet("Foo", "src/a/Foo.sol");
    const fooB = facet("Foo", "src/b/Foo.sol");

    const selected = buildVirtualStorageLayout(sources, [fooB]);
    expect(selected.records).toEqual([
      expect.objectContaining({
        contractName: "Foo",
        layout: ["0x03"],
        sourceName: "src/b/Foo.sol",
        slots: [[160]],
      }),
    ]);

    expect(buildVirtualStorageLayout(sources, [fooA, fooB]).collisions).toEqual([
      expect.objectContaining({
        id: `0x${"0".repeat(64)}`,
        virtualPath: "0x0",
        mismatches: expect.arrayContaining([expect.objectContaining({
          left: expect.objectContaining({ variableName: "value" }),
          right: expect.objectContaining({ variableName: "value" }),
        })]),
      }),
    ]);
  });

  it("keeps full paths and container kinds for nested virtual records", () => {
    const result = buildVirtualStorageLayout(
      [nestedVirtualPathAstSource()],
      [facet("PathFacet", "src/PathFacet.sol")],
    );

    expect(result.records.map((record) => ({
      id: record.id,
      kind: record.kind,
      path: record.virtualPath,
    }))).toEqual([
      {
        id: hashVirtualPath("erc20"),
        kind: "normal",
        path: "erc20",
      },
      {
        id: hashVirtualPath("erc20.5"),
        kind: "normal",
        path: "erc20.5",
      },
      {
        id: hashVirtualPath("erc20.5.3"),
        kind: "immutable",
        path: "erc20.5.3",
      },
    ]);
  });

  it("preserves the physical span of packed structs in fixed arrays", () => {
    const result = buildVirtualStorageLayout(
      [fixedArrayStructAstSource()],
      [facet("FixedArrayFacet", "src/FixedArrayFacet.sol")],
    );

    expect(result.warnings).toEqual([]);
    expect(result.collisions).toEqual([]);
    expect(result.records.map((record) => ({
      kind: record.kind,
      path: record.virtualPath,
      slots: record.slots,
    }))).toEqual([
      {
        kind: "normal",
        path: "fixed.struct",
        slots: [
          [8, 96],
          [8, 96],
          [8, 96],
          [8, 96],
          [8, 96],
          [256],
        ],
      },
      {
        kind: "immutable",
        path: "fixed.struct.0",
        slots: [[8, 96]],
      },
      {
        kind: "normal",
        path: "fixed.struct.5",
        slots: [[256]],
      },
    ]);
  });

  it("isolates storage layouts between diamonds", () => {
    const source = independentDiamondAstSource();

    expect(buildVirtualStorageLayout(
      [source],
      [
        facet("AlphaFacet", "src/IndependentFacets.sol"),
        facet("BetaFacet", "src/IndependentFacets.sol"),
      ],
    ).collisions).toHaveLength(1);

    const scoped = buildScopedVirtualStorageLayout([source], [
      { diamondName: "Alpha", facets: [facet("AlphaFacet", "src/IndependentFacets.sol")] },
      { diamondName: "Beta", facets: [facet("BetaFacet", "src/IndependentFacets.sol")] },
    ]);

    expect(scoped.collisions).toEqual([]);
    expect(scoped.records.map((item) => item.diamondName)).toEqual(["Alpha", "Beta"]);
  });

  it("reports storage contradictions inside the same diamond", () => {
    const result = buildScopedVirtualStorageLayout([independentDiamondAstSource()], [{
      diamondName: "SharedDiamond",
      facets: [
        facet("AlphaFacet", "src/IndependentFacets.sol"),
        facet("BetaFacet", "src/IndependentFacets.sol"),
      ],
    }]);

    expect(result.collisions).toEqual([
      expect.objectContaining({
        diamondName: "SharedDiamond",
        id: `0x${"0".repeat(64)}`,
        virtualPath: "0x0",
      }),
    ]);
  });

  it("builds the canonical layout and packing from compiler AST", () => {
    const result = buildVirtualStorageLayout(
      [normalAstSource()],
      [facet("Normal", "project/contracts/Normal.sol")],
    );

    expect(result.warnings).toEqual([]);
    expect(result.collisions).toEqual([]);
    expect(result.records).toHaveLength(1);
    expect(result.records[0]).toEqual({
      id: "0xb4df32537f6767405c9db7d67260e5375218aecdea91f4240ad14000623cbdff",
      virtualPath: "evmole.normal",
      kind: "normal",
      codeWidth: 1,
      layout: [
        "0x2f", "0x53", "0xf4", "0x53", "0xf4", "0x53", "0x17", "0x10",
        "0xff", "0x13", "0xff", "0xf1", "0x03", "0x2f", "0xff", "0xf1",
        "0x03", "0xf1", "0x03", "0x2f", "0xff", "0xf2", "0x10", "0xff",
      ],
      serializedLayout: [
        "0x01", "0x2f", "0x53", "0xf4", "0x53", "0xf4", "0x53", "0x17",
        "0x10", "0xff", "0x13", "0xff", "0xf1", "0x03", "0x2f", "0xff",
        "0xf1", "0x03", "0xf1", "0x03", "0x2f", "0xff", "0xf2", "0x10", "0xff",
      ],
      slots: [[256], [32], [32], [32, 64, 8], [32], [256], [256], [256]],
      source: "slot-assignment",
      sourceName: "project/contracts/Normal.sol",
      contractName: "Normal",
      structName: "NormalStorage",
    });
  });

  it("ignores compiled contracts outside the selected facet graph", () => {
    const source: SolidityAstSource = {
      sourceName: "src/OtherFacet.sol",
      ast: {
        id: 8000,
        nodeType: "SourceUnit",
        src: "0:0:0",
        nodes: [{
          contractKind: "contract",
          id: 8001,
          linearizedBaseContracts: [8001],
          name: "OtherFacet",
          nodeType: "ContractDefinition",
          nodes: [],
        }],
      },
    };
    const result = buildVirtualStorageLayout(
      [normalAstSource(), source],
      [facet("OtherFacet", "src/OtherFacet.sol")],
    );

    expect(result.records).toEqual([]);
    expect(result.collisions).toEqual([]);
    expect(result.warnings).toEqual([{
      sourceName: "src/OtherFacet.sol",
      message: "OtherFacet: no storage pattern found; storage validation skipped for this facet.",
    }]);
  });

  it("keeps only referenced roots from a reachable storage library", () => {
    const result = buildVirtualStorageLayout(
      [libraryReachabilityAstSource()],
      [facet("ReachableFacet", "src/ReachableFacet.sol")],
    );

    expect(result.records.map((item) => ({ id: item.id, path: item.virtualPath }))).toEqual([{
      id: "0x5beaa2863186d437dda8f3099114cae898c8516639341d5786ade60d517a8a90",
      path: "used.storage",
    }]);
  });

  it("accepts append-only roots and rejects clear type contradictions", () => {
    expect(findVirtualStorageLayoutCollisions([
      record(["0x2f"]),
      record(["0x2f", "0x03"]),
    ])).toEqual([]);

    expect(findVirtualStorageLayoutCollisions([
      record(["0x2f", "0xfe"]),
      record(["0x10", "0x03"]),
    ])).toEqual([
      expect.objectContaining({
        id: "0x1b0734a7bedafd59afc4f0cdc0bb15fd1c76495dc1393123b69bf74b08e29564",
        virtualPath: "shared.storage",
        reason: "normal layout is not append-only compatible",
      }),
    ]);

    expect(findVirtualStorageLayoutCollisions([
      record(["0x2f", "0xfe"]),
      record(["0x2f", "0x03"]),
    ])).toEqual([]);

    expect(findUnsupportedVirtualStorageLayouts([
      record(["0x2f", "0xfe"]),
      record(["0x2f", "0x03"]),
    ])).toEqual([
      expect.objectContaining({
        virtualPath: "shared.storage",
        reason: "layout contains an unknown storage type",
      }),
    ]);

    expect(findUnsupportedVirtualStorageLayouts([
      record(["0x2f", "0x71"]),
      record(["0x2f", "0x03"]),
    ])).toEqual([]);
  });
});
