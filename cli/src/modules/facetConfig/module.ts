import type { ComposeContext } from "../../context/types";
import {
  installFromManifest,
  installSelectedFacets,
  removeFromManifest,
  removeSelectedFacets,
} from "./operations";
import { loadComposeProject } from "./projectConfig";
import { selectDiamond } from "./selection";
import type { FacetBatchOperation } from "./types";

/** Rejects flag combinations the CLI cannot honor before any project state is touched. */
function assertExclusiveFacetParams(ctx: ComposeContext): void {
  if (ctx.param.manifest && ctx.param.createManifest) {
    throw new Error("Use either --manifest or --create-manifest, not both.");
  }
  if (ctx.param.manifest && Array.isArray(ctx.param.facets) && ctx.param.facets.length > 0) {
    throw new Error("Use either facet arguments or --manifest, not both.");
  }
}

/** A batch manifest defines its own diamonds; a second one on the command line would be ambiguous. */
function assertManifestOwnsDiamond(ctx: ComposeContext): void {
  if (ctx.param.diamond) {
    throw new Error("The diamond is defined by the manifest; omit --diamond when using --manifest.");
  }
}

export const FacetConfigModule = {
  async execute(ctx: ComposeContext, operation: FacetBatchOperation): Promise<ComposeContext> {
    assertExclusiveFacetParams(ctx);
    const project = await loadComposeProject(ctx);

    if (ctx.param.manifest) {
      assertManifestOwnsDiamond(ctx);
      return operation === "install" ? installFromManifest(ctx, project) : removeFromManifest(ctx, project);
    }

    const diamondName = await selectDiamond(
      ctx,
      Object.keys(project.config.diamonds),
      operation === "install" ? "install facets into" : "remove facets from",
    );
    return operation === "install"
      ? installSelectedFacets(ctx, project, diamondName)
      : removeSelectedFacets(ctx, project, diamondName);
  },
};
