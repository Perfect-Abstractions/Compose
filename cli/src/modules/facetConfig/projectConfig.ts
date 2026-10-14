import { ComposeContext } from "../../context/types";
import { atomicWriteFile } from "../../utils/files";
import { locateComposeProjectFile, readComposeProjectFile } from "../../utils/composeProjectFile";
import type { ComposeProjectConfig } from "./types";

export type LoadedComposeProject = {
  path: string;
  root: string;
  config: ComposeProjectConfig;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export async function loadComposeProject(ctx: ComposeContext): Promise<LoadedComposeProject> {
  const startDirectory = String(ctx.param.projectRoot ?? process.cwd());
  const composeProjectFile = await locateComposeProjectFile(startDirectory);
  if (!composeProjectFile) {
    throw new Error("compose.json not found. Run 'compose init' or navigate to a Compose project directory.");
  }

  let raw: unknown;
  try {
    raw = await readComposeProjectFile(composeProjectFile.path);
  } catch (error) {
    const message = error instanceof Error ? error.message : "unknown JSON parse error";
    throw new Error(`Unable to parse ${composeProjectFile.path}: ${message}`, { cause: error });
  }

  if (!isRecord(raw) || !isRecord(raw.diamonds) || Object.keys(raw.diamonds).length === 0) {
    throw new Error(`${composeProjectFile.path} must contain a non-empty diamonds object.`);
  }

  for (const [diamondName, diamond] of Object.entries(raw.diamonds)) {
    if (!diamondName.trim() || !isRecord(diamond) || typeof diamond.contract !== "string") {
      throw new Error(`Diamond '${diamondName || "<empty>"}' must define a contract reference.`);
    }
    if (diamond.facets === undefined) diamond.facets = {};
    if (!isRecord(diamond.facets)) {
      throw new Error(`Diamond '${diamondName}' facets must be an object.`);
    }
  }

  const config = raw as ComposeProjectConfig;
  if (config.framework !== "foundry" && config.framework !== "hardhat") {
    throw new Error(`Unsupported framework in compose.json: ${String(config.framework ?? "missing")}.`);
  }

  const projectRoot = composeProjectFile.root;
  ctx.param.projectRoot = projectRoot;
  ctx.param.framework = config.framework;
  ctx.config.composeJson = config as Record<string, unknown>;
  ctx.state.facetProjectConfig = {
    success: true,
    result: { path: composeProjectFile.path, projectRoot },
    error: null,
  };

  return { path: composeProjectFile.path, root: projectRoot, config };
}

export async function writeComposeProject(
  project: LoadedComposeProject,
  config: ComposeProjectConfig,
): Promise<void> {
  await atomicWriteFile(project.path, `${JSON.stringify(config, null, 2)}\n`);
}
