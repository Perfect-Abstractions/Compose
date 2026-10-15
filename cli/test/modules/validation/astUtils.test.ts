import { describe, expect, it } from "vitest";
import {
  astNode,
  childNodes,
  numberArray,
  stringValue,
  walkAst,
  walkAstWithAncestors,
  walkAstWithContract,
  type AstNode,
} from "../../../src/modules/validation/astUtils";

describe("validation AST utilities", () => {
  it("recognizes only non-array objects with a string node type", () => {
    const node = { nodeType: "Identifier", name: "value" };

    expect(astNode(node)).toBe(node);
    expect(astNode(null)).toBeNull();
    expect(astNode([node])).toBeNull();
    expect(astNode({ name: "value" })).toBeNull();
    expect(astNode({ nodeType: 1 })).toBeNull();
  });

  it("filters child arrays to AST nodes and safely converts primitive values", () => {
    const parent = {
      nodeType: "SourceUnit",
      children: [
        { nodeType: "Identifier", name: "first" },
        null,
        { name: "not-an-ast-node" },
        { nodeType: "Identifier", name: "second" },
      ],
    } as AstNode;

    expect(childNodes(parent, "children").map((node) => node.name)).toEqual(["first", "second"]);
    expect(childNodes(parent, "missing")).toEqual([]);
    expect(numberArray([1, "2", 3, null])).toEqual([1, 3]);
    expect(numberArray("1,2")).toEqual([]);
    expect(stringValue("value")).toBe("value");
    expect(stringValue(1)).toBe("");
  });

  it("walks in object and array order and reports ancestors without the current node", () => {
    const ast: AstNode = {
      nodeType: "SourceUnit",
      nodes: [{
        nodeType: "ContractDefinition",
        id: 10,
        nodes: [{
          nodeType: "FunctionDefinition",
          id: 11,
          body: {
            nodeType: "Block",
            statements: [
              { nodeType: "Identifier", name: "first" },
              { nodeType: "Identifier", name: "second" },
            ],
          },
        }],
      }],
    };
    const visited: string[] = [];
    const identifierAncestors: string[][] = [];

    walkAst(ast, (node) => visited.push(node.nodeType));
    walkAstWithAncestors(ast, (node, ancestors) => {
      if (node.nodeType === "Identifier") {
        identifierAncestors.push(ancestors.map((ancestor) => ancestor.nodeType));
      }
    });

    expect(visited).toEqual([
      "SourceUnit",
      "ContractDefinition",
      "FunctionDefinition",
      "Block",
      "Identifier",
      "Identifier",
    ]);
    expect(identifierAncestors).toEqual([
      ["SourceUnit", "ContractDefinition", "FunctionDefinition", "Block"],
      ["SourceUnit", "ContractDefinition", "FunctionDefinition", "Block"],
    ]);
  });

  it("tracks the current enclosing contract ID", () => {
    const ast: AstNode = {
      nodeType: "SourceUnit",
      nodes: [
        {
          nodeType: "ContractDefinition",
          id: 10,
          nodes: [
            { nodeType: "FunctionDefinition", id: 11 },
            {
              nodeType: "ContractDefinition",
              id: 20,
              nodes: [{ nodeType: "FunctionDefinition", id: 21 }],
            },
          ],
        },
        { nodeType: "FunctionDefinition", id: 30 },
      ],
    };
    const ownership: Array<[string, number | null]> = [];

    walkAstWithContract(ast, null, (node, ownerContractId) => {
      ownership.push([node.nodeType, ownerContractId]);
    });

    expect(ownership).toEqual([
      ["SourceUnit", null],
      ["ContractDefinition", 10],
      ["FunctionDefinition", 10],
      ["ContractDefinition", 20],
      ["FunctionDefinition", 20],
      ["FunctionDefinition", null],
    ]);
  });
});
