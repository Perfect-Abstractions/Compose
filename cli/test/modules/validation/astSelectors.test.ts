import { describe, expect, it, vi } from "vitest";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {
  IFrameworkAdapter,
  SolidityAstSource,
} from "../../../src/adapters/interface/IFrameworkAdapter";
import { HashingAdapter } from "../../../src/adapters/hashingAdapter";
import { Context } from "../../../src/context/context";
import { ModuleState } from "../../../src/context/types";
import { ValidationModule } from "../../../src/modules/validation/module";
import {
  FacetScanStateResult,
  SelectorExportValidationResult,
} from "../../../src/modules/validation/types";
import { ValidatePipeline } from "../../../src/pipelines/validatePipeline";
import { DependencyResolver } from "../../../src/resolver/dependencyResolver";

const parameter = (id: number, name: string) => ({
  id,
  nodeType: "VariableDeclaration",
  typeName: { id: id + 100, name, nodeType: "ElementaryTypeName" },
});

const functionNode = (
  id: number,
  name: string,
  visibility: "external" | "public",
  parameters: unknown[] = [],
) => ({
  id,
  kind: "function",
  name,
  nodeType: "FunctionDefinition",
  parameters: { id: id + 200, nodeType: "ParameterList", parameters },
  visibility,
});

const selectorReference = (id: number, functionId: number, name: string) => ({
  expression: {
    expression: { id: id + 2, name: "this", nodeType: "Identifier" },
    id: id + 1,
    memberName: name,
    nodeType: "MemberAccess",
    referencedDeclaration: functionId,
  },
  id,
  memberName: "selector",
  nodeType: "MemberAccess",
});

const astSources: SolidityAstSource[] = [
  {
    sourceName: "src/SelectorFacet.sol",
    ast: {
      id: 1000,
      nodeType: "SourceUnit",
      src: "0:0:0",
      nodes: [
        {
          id: 10,
          linearizedBaseContracts: [10],
          name: "BaseFacet",
          nodeType: "ContractDefinition",
          nodes: [
            functionNode(11, "foo", "external", [parameter(12, "uint256")]),
            functionNode(13, "bar", "public", [parameter(14, "address")]),
          ],
        },
        {
          id: 20,
          linearizedBaseContracts: [20, 10],
          name: "SelectorFacet",
          nodeType: "ContractDefinition",
          nodes: [
            functionNode(21, "baz", "external"),
            {
              body: {
                id: 24,
                nodeType: "Block",
                statements: [
                  selectorReference(25, 11, "foo"),
                  selectorReference(28, 21, "baz"),
                ],
              },
              id: 22,
              kind: "function",
              name: "exportSelectors",
              nodeType: "FunctionDefinition",
              parameters: { id: 23, nodeType: "ParameterList", parameters: [] },
              visibility: "external",
            },
          ],
        },
      ],
    },
  },
];

describe("ValidationModule AST selector scan", () => {
  it("uses source path to disambiguate contracts with the same name", () => {
    const ctx = Context.create();
    const duplicateSources: SolidityAstSource[] = [
      namedContractSource("src/a/Foo.sol", 3000, "fromA"),
      namedContractSource("src/b/Foo.sol", 4000, "fromB"),
    ];

    ValidationModule.scanFacetSelectors(ctx, duplicateSources, [{
      contractName: "Foo",
      sourcePath: "src/b/Foo.sol",
    }]);

    const scan = ctx.state.facetScan as ModuleState<FacetScanStateResult>;
    expect(scan.result?.facets).toEqual([
      expect.objectContaining({
        facetName: "Foo",
        path: "src/b/Foo.sol",
        functions: [expect.objectContaining({ signature: "fromB()" })],
      }),
    ]);
  });

  it("resolves inherited functions and reports missing exports as warnings", async () => {
    const ctx = Context.create();

    ValidationModule.scanFacetSelectors(ctx, astSources, [{
      contractName: "SelectorFacet",
      sourcePath: "src/SelectorFacet.sol",
    }]);
    await ValidationModule.validateSelectorExports(ctx);

    const scan = ctx.state.facetScan as ModuleState<FacetScanStateResult>;
    const facet = scan.result?.facets[0];
    const validation = ctx.state.validationSelectorExports as ModuleState<SelectorExportValidationResult>;

    if (!facet) {
      throw new Error("SelectorFacet scan result was not produced.");
    }

    expect(facet.functions.map((fn) => fn.signature)).toEqual([
      "baz()",
      "foo(uint256)",
      "bar(address)",
    ]);
    expect(facet.exportedSelectors).toEqual(["foo(uint256)", "baz()"]);
    expect(facet.missingExports).toEqual(["bar(address)"]);
    expect(validation.success).toBe(true);
    expect(validation.result?.issues).toEqual([
      {
        facetName: "SelectorFacet",
        path: "src/SelectorFacet.sol",
        missingExportSelectorsFunction: false,
        missingExports: ["bar(address)"],
        extraExports: [],
      },
    ]);
    expect(ValidationModule.hasSelectorExportFailure(ctx)).toBe(false);
  });

  it("warns when a facet does not declare exportSelectors", async () => {
    const ctx = Context.create();

    ValidationModule.scanFacetSelectors(ctx, astSources, [{
      contractName: "BaseFacet",
      sourcePath: "src/SelectorFacet.sol",
    }]);
    await ValidationModule.validateSelectorExports(ctx);

    const validation = ctx.state.validationSelectorExports as ModuleState<SelectorExportValidationResult>;

    expect(validation.success).toBe(true);
    expect(validation.result?.issues).toEqual([
      {
        facetName: "BaseFacet",
        path: "src/SelectorFacet.sol",
        missingExportSelectorsFunction: true,
        missingExports: ["foo(uint256)", "bar(address)"],
        extraExports: [],
      },
    ]);
  });

  it("runs from the validate command using compose.json project inputs", async () => {
    const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-validate-command-"));
    const ctx = Context.create();
    const compileAst = vi.fn(async () => astSources);
    const adapter = { compileAst } as unknown as IFrameworkAdapter;
    const resolveDependencies = vi.spyOn(DependencyResolver, "resolve").mockResolvedValue({
      foundry: adapter,
      hashing: HashingAdapter,
    });
    const detectSelectorCollisions = vi.spyOn(ValidationModule, "detectSelectorCollisions");
    const buildVirtualStorageLayout = vi.spyOn(ValidationModule, "buildVirtualStorageLayout");
    const output = vi.spyOn(console, "log").mockImplementation(() => undefined);

    try {
      await fs.writeFile(
        path.join(projectRoot, "compose.json"),
        JSON.stringify({
          framework: "foundry",
          diamonds: {
            Example: {
              contract: "src/Diamond.sol:Diamond",
              facets: {
                SelectorFacet: {
                  source: "local",
                  contract: "src/SelectorFacet.sol:SelectorFacet",
                },
              },
            },
          },
        }),
        "utf8",
      );
      ctx.param.command = "validate";
      ctx.param.projectRoot = projectRoot;

      const result = await ValidatePipeline.execute(ctx);

      expect(result.status.success).toBe(true);
      expect(result.state.validationProject?.success).toBe(true);
      expect(result.state.validatePipeline?.success).toBe(true);
      expect(compileAst).toHaveBeenCalledWith(ctx, [
        path.join(projectRoot, "src", "SelectorFacet.sol"),
      ]);
      expect(detectSelectorCollisions).toHaveBeenCalledWith(ctx, {
        hashing: HashingAdapter,
        scopes: [{
          diamondName: "Example",
          facets: [{
            contractName: "SelectorFacet",
            sourcePath: path.join(projectRoot, "src", "SelectorFacet.sol"),
          }],
        }],
      });
      expect(buildVirtualStorageLayout).toHaveBeenCalledWith(
        ctx,
        astSources,
        [{
          contractName: "SelectorFacet",
          sourcePath: path.join(projectRoot, "src", "SelectorFacet.sol"),
        }],
        [{
          diamondName: "Example",
          facets: [{
            contractName: "SelectorFacet",
            sourcePath: path.join(projectRoot, "src", "SelectorFacet.sol"),
          }],
        }],
      );
      expect(output.mock.calls.flat().some((value) => String(value).includes("Validation passed")))
        .toBe(true);
    } finally {
      output.mockRestore();
      detectSelectorCollisions.mockRestore();
      buildVirtualStorageLayout.mockRestore();
      resolveDependencies.mockRestore();
      await fs.rm(projectRoot, { recursive: true, force: true });
    }
  });
});

function namedContractSource(
  sourceName: string,
  id: number,
  functionName: string,
): SolidityAstSource {
  return {
    sourceName,
    ast: {
      id: id + 100,
      nodeType: "SourceUnit",
      src: "0:0:0",
      nodes: [{
        id,
        linearizedBaseContracts: [id],
        name: "Foo",
        nodeType: "ContractDefinition",
        nodes: [functionNode(id + 1, functionName, "external")],
      }],
    },
  };
}
