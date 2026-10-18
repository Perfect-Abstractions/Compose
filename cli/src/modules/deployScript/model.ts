import path from "node:path";
import { randomUUID } from "node:crypto";
import type { IHashingAdapter } from "../../adapters/IHashingAdapter/interface";
import { toPosixPath } from "../../utils/files";
import type { DeployGenerationModel } from "../deployGeneration/types";
import { matchesAstSource } from "../validation/astIdentity";
import type { FacetScanResult } from "../validation/types";
import type { DeployProject, DeployScriptArtifact } from "./types";

export type DeploymentReferences = { diamond: string; facets: string[] };

/** Build the renderer model from the selected composition and framework identities. */
export function buildDeployScriptModel(
  project: DeployProject,
  references: DeploymentReferences,
  generatedAt: string,
): DeployGenerationModel {
  const safeName = project.diamondName.replace(/[^A-Za-z0-9_-]/g, "_") || "diamond";
  const extension = project.framework === "foundry" ? "s.sol" : "ts";
  const filename = `${generatedAt.replace(/[-:.]/g, "")}-deploy-${safeName}-${randomUUID().slice(0, 8)}.${extension}`;
  return {
    outputPath: path.join(project.projectRoot, "compose-scripts", project.chain.key, filename),
    projectRoot: project.projectRoot,
    diamond: {
      contractName: project.diamond.contractName,
      importPath: project.diamond.reference.slice(0, project.diamond.reference.lastIndexOf(":")),
      deploymentReference: references.diamond,
    },
    facets: project.facets.map((facet, index) => ({
      facetName: facet.name,
      contractName: facet.contractName,
      origin: facet.origin,
      group: "base",
      importPath: toPosixPath(path.relative(project.projectRoot, facet.sourcePath)),
      deploymentReference: references.facets[index],
    })),
  };
}

/** Attach source-side selector evidence without implying that the script has executed. */
export function buildDeployScriptArtifact(
  project: DeployProject,
  references: DeploymentReferences,
  model: DeployGenerationModel,
  generatedAt: string,
  toolbox: DeployScriptArtifact["toolbox"],
  scans: FacetScanResult[],
  hashing: IHashingAdapter,
): DeployScriptArtifact {
  return {
    kind: "deployment-script",
    outputPath: model.outputPath,
    generatedAt,
    composeJsonPath: project.composeJsonPath,
    diamondName: project.diamondName,
    diamond: { ...project.diamond, artifactReference: references.diamond },
    chain: project.chain,
    framework: project.framework,
    toolbox,
    selectorEvidence: "source-ast",
    facets: project.facets.map((facet, index) => {
      const scan = scans.find((candidate) =>
        candidate.facetName === facet.contractName && matchesAstSource(candidate.path, facet.sourcePath),
      );
      if (!scan) throw new Error(`Missing selector evidence for ${facet.reference}.`);
      return {
        name: facet.name,
        reference: facet.reference,
        sourcePath: facet.sourcePath,
        contractName: facet.contractName,
        artifactReference: references.facets[index],
        expectedSelectors: scan.hasExportSelectorsFunction
          ? scan.exportedSelectors.map((signature) => hashing.keccak256(signature).slice(0, 10))
          : null,
      };
    }),
  };
}
