import fs from "node:fs/promises";
import path from "node:path";
import type { ComposeContext } from "../../context/types";
import { findFileAncestor, toPosixPath } from "../../utils/files";
import { loadPrompts, selectTheme } from "../../utils/inquirer";
import { resolveComposeProjectFacetSources } from "../validation/projectSourceResolution";
import type { DeployContract, DeployProject } from "./types";

function object(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object.`);
  return value as Record<string, unknown>;
}

function contract(projectRoot: string, reference: unknown): DeployContract {
  if (typeof reference !== "string") throw new Error("Contract reference must be path.sol:ContractName.");
  const separator = reference.lastIndexOf(":");
  const source = reference.slice(0, separator);
  const contractName = reference.slice(separator + 1);
  if (separator <= 0 || !/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(contractName)) {
    throw new Error(`Invalid contract reference: ${reference}. Expected path.sol:ContractName.`);
  }
  const sourcePath = path.resolve(projectRoot, source);
  return { reference: `${toPosixPath(path.relative(projectRoot, sourcePath))}:${contractName}`, sourcePath, contractName };
}

/** Resolve only the requested diamond, without depending on init or scaffold state. */
export async function loadDeployProject(ctx: ComposeContext): Promise<DeployProject> {
  const composeJsonPath = await findFileAncestor(path.resolve(String(ctx.param.projectRoot ?? process.cwd())), "compose.json");
  if (!composeJsonPath) throw new Error("compose.json not found. Run 'compose init' first.");
  const config = object(JSON.parse(await fs.readFile(composeJsonPath, "utf8")), "compose.json");
  const projectRoot = path.dirname(composeJsonPath);
  const framework = config.framework;
  if (framework !== "foundry" && framework !== "hardhat") throw new Error("compose.json must specify foundry or hardhat.");
  const diamonds = object(config.diamonds, "diamonds");
  const names = Object.keys(diamonds);
  let diamondName = ctx.param.diamond;
  if (diamondName === undefined && names.length === 1) diamondName = names[0];
  if (diamondName === undefined && names.length > 1 && process.stdin.isTTY && process.stdout.isTTY && !ctx.param.yes) {
    diamondName = await (await loadPrompts()).select({
      message: "Select the diamond to generate a deployment script for:",
      choices: names.map((name) => ({ name, value: name })), theme: selectTheme,
    });
  }
  if (typeof diamondName !== "string" || !Object.hasOwn(diamonds, diamondName)) {
    throw new Error(`Specify a diamond from compose.json. Available: ${names.join(", ") || "none"}.`);
  }
  const selected = object(diamonds[diamondName], `Diamond ${diamondName}`);
  if (selected.init !== undefined) throw new Error("Diamond init configuration is not supported yet. Keep initialization in the contract constructor.");
  const entries = Object.entries(object(selected.facets, "facets"));
  if (entries.length === 0) throw new Error(`Diamond '${diamondName}' has no facets.`);
  const facets: DeployProject["facets"] = [];
  for (const [name, raw] of entries) {
    const facet = object(raw, `Facet ${name}`);
    if (facet.source === "local") {
      facets.push({ ...contract(projectRoot, facet.contract), name, origin: "local" });
    } else if (facet.source === "package") {
      if (typeof facet.package !== "string" || !facet.package.trim() || typeof facet.contract !== "string") {
        throw new Error(`Package facet '${name}' must specify package and contract.`);
      }
      const contractName = facet.contract.includes(":") ? facet.contract.slice(facet.contract.lastIndexOf(":") + 1) : facet.contract;
      const [resolved] = await resolveComposeProjectFacetSources(projectRoot, [{ contractName, packageName: facet.package }]);
      facets.push({ ...contract(projectRoot, `${resolved.sourcePath}:${contractName}`), name, origin: "package" });
    } else throw new Error(`Unsupported facet source for '${name}': ${String(facet.source)}.`);
  }
  const key = ctx.param.chain ?? "local";
  if (typeof key !== "string" || !/^[A-Za-z0-9_-]+$/.test(key)) throw new Error("Invalid deployment chain key.");
  const chain = object(object(config.chains, "chains")[key], `Chain ${key}`);
  if (!Number.isSafeInteger(chain.chainId) || Number(chain.chainId) <= 0) throw new Error(`Invalid chainId for '${key}'.`);
  return { projectRoot, composeJsonPath, framework, diamondName, diamond: contract(projectRoot, selected.contract), facets, chain: { key, chainId: Number(chain.chainId) } };
}
