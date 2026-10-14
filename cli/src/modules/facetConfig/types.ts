import type { ConstructorEntry, Erc165Entry } from "../config/types";

export type FacetRegistration = {
  source: "local" | "package";
  contract: string;
  package?: string;
  mod?: string;
  constructor: ConstructorEntry[] | undefined;
  erc165?: Erc165Entry;
};

/**
 * A diamond entry in `compose.json`.
 *
 * Entries read back from disk are only validated as an object container
 * (`projectConfig.ts`), so stored facet values are compared defensively as
 * `unknown` (`sameRegistration`) rather than trusted as `FacetRegistration`.
 */
export type ComposeDiamondConfig = {
  contract: string;
  facets: Record<string, FacetRegistration>;
  [key: string]: unknown;
};

export type ComposeProjectConfig = {
  project?: string;
  compose?: string;
  framework?: string;
  diamonds: Record<string, ComposeDiamondConfig>;
  [key: string]: unknown;
};

export type CatalogFacetReference = {
  name: string;
  source?: undefined;
};

export type LocalFacetReference = {
  name: string;
  source: "local";
  contract: string;
};

export type PackageFacetReference = {
  name: string;
  source: "package";
  contract: string;
  package: string;
};

export type FacetInstallReference =
  | CatalogFacetReference
  | LocalFacetReference
  | PackageFacetReference;

export type InstallFacetBatch = {
  version: 1;
  operation: "install";
  diamonds: Record<string, FacetInstallReference[]>;
};

export type RemoveFacetBatch = {
  version: 1;
  operation: "remove";
  diamonds: Record<string, string[]>;
};

export type FacetBatch = InstallFacetBatch | RemoveFacetBatch;

export type ResolvedFacetInstall = {
  name: string;
  contractName?: string;
  registration: FacetRegistration;
  catalogSource?: string;
  targetGroup?: "diamond" | "libraries" | "facets";
};

export type FacetBatchOperation = "install" | "remove";

export type FacetMutationResult = {
  operation: FacetBatchOperation;
  projectRoot: string;
  composeJsonPath: string;
  diamondChanges: Array<{
    diamond: string;
    facets: string[];
  }>;
  changed: boolean;
  materializedFiles?: string[];
  manifestPath?: string;
};
