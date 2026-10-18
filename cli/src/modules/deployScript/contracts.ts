import type { SolidityAstSource } from "../../adapters/IFrameworkAdapter/interface";
import { matchesAstSource } from "../validation/astIdentity";
import type { DeployContract, DeployProject } from "./types";

type Node = Record<string, unknown>;

/** Check supported constructor shapes before emitting a script with implicit arguments. */
export function validateDeployConstructors(project: DeployProject, sources: SolidityAstSource[]): void {
  const check = (identity: DeployContract, diamond: boolean): void => {
    const matches = sources.filter((source) => matchesAstSource(source.sourceName, identity.sourcePath))
      .flatMap((source) => source.ast.nodes ?? [])
      .filter((node): node is Node => Boolean(node) && typeof node === "object")
      .filter((node) => node.nodeType === "ContractDefinition" && node.name === identity.contractName);
    if (matches.length !== 1) throw new Error(`Contract not found or ambiguous in compiler AST: ${identity.reference}`);
    const definition = matches[0];
    if (definition.abstract === true || definition.contractKind !== "contract") throw new Error(`Contract is not deployable: ${identity.reference}`);
    const nodes = (definition.nodes ?? []) as Node[];
    const constructor = nodes.find((node) => node.nodeType === "FunctionDefinition" && node.kind === "constructor");
    const parameters = (constructor?.parameters as { parameters?: Node[] } | undefined)?.parameters ?? [];
    const type = parameters[0]?.typeDescriptions as { typeString?: string } | undefined;
    const supported = diamond
      ? parameters.length === 1 && /^address\[\]( memory)?$/.test(type?.typeString ?? "")
      : parameters.length === 0;
    if (!supported) throw new Error(`Unsupported constructor for ${identity.reference}. Expected ${diamond ? "one address[] facet argument" : "no arguments"}.`);
  };
  check(project.diamond, true);
  project.facets.forEach((facet) => check(facet, false));
}
