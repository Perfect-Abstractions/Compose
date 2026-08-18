import { IFrameworkAdapter } from "../../adapters/interface/IFrameworkAdapter";
import { ComposeContext, ModuleState } from "../../context/types";
import { ScaffoldMapEntry } from "../scaffolding/types";
import { ResolvedFacetSource, ResolvedFacetSourceResult } from "./types";

type FacetOrigin = ScaffoldMapEntry["origin"];

/** Resolves one scaffold-map origin into framework compilation paths. */
export async function resolveFacetSources(
  ctx: ComposeContext,
  adapter: IFrameworkAdapter,
  origin: FacetOrigin,
): Promise<ResolvedFacetSource[]> {
  const scaffoldMap = ctx.state.scaffoldMap as
    | ModuleState<{ entries: ScaffoldMapEntry[] }>
    | undefined;
  const entries = scaffoldMap?.result?.entries ?? [];

  return Promise.all(
    entries
      .filter((entry) => entry.origin === origin)
      .map(async (entry) => ({
        contractName: entry.contractName,
        sourcePath: await adapter.resolveSoliditySourcePath(ctx, entry.targetPath),
      })),
  );
}

/** Reads and merges package and project facet compilation inputs. */
export function getResolvedFacetSources(ctx: ComposeContext): ResolvedFacetSource[] {
  const composeSources = ctx.state.validationComposeFacetSources as
    | ModuleState<ResolvedFacetSourceResult>
    | undefined;
  const projectSources = ctx.state.validationProjectFacetSources as
    | ModuleState<ResolvedFacetSourceResult>
    | undefined;

  return [
    ...(composeSources?.result?.sources ?? []),
    ...(projectSources?.result?.sources ?? []),
  ];
}
