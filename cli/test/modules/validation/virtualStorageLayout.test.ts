import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { SolidityAstSource } from "../../../src/adapters/interface/IFrameworkAdapter";
import { VirtualStorageLayoutRecord } from "../../../src/modules/validation/types";
import {
  buildVirtualStorageLayout,
  findVirtualStorageLayoutCollisions,
} from "../../../src/modules/validation/virtualStorageLayout";

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
    id: "shared.storage",
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

describe("virtual storage layout", () => {
  it("builds the canonical layout and packing from compiler AST", () => {
    const result = buildVirtualStorageLayout([normalAstSource()], ["Normal"]);

    expect(result.warnings).toEqual([]);
    expect(result.collisions).toEqual([]);
    expect(result.records).toHaveLength(1);
    expect(result.records[0]).toEqual({
      id: "evmole.normal",
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
    const result = buildVirtualStorageLayout([normalAstSource()], ["OtherFacet"]);

    expect(result.records).toEqual([]);
    expect(result.collisions).toEqual([]);
    expect(result.warnings).toEqual([{
      sourceName: "OtherFacet",
      message: "OtherFacet: no storage pattern found; storage validation skipped for this facet.",
    }]);
  });

  it("keeps only referenced roots from a reachable storage library", () => {
    const result = buildVirtualStorageLayout(
      [libraryReachabilityAstSource()],
      ["ReachableFacet"],
    );

    expect(result.records.map((item) => item.id)).toEqual(["used.storage"]);
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
        id: "shared.storage",
        reason: "normal layout is not append-only compatible",
      }),
    ]);

    expect(findVirtualStorageLayoutCollisions([
      record(["0x2f", "0xfe"]),
      record(["0x2f", "0x03"]),
    ])).toEqual([]);
  });
});
