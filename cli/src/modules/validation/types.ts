import { IHashingAdapter } from "../../adapters/interface/IHashingAdapter";

export type FunctionInfo = {
  name: string;
  signature: string;
  visibility: "external" | "public";
};

export type FacetScanResult = {
  facetName: string;
  path: string;
  functions: FunctionInfo[];
  exportedSelectors: string[];
  missingExports: string[];
  extraExports: string[];
  storageLayouts: StorageLayoutInfo[];
};

export type FacetScanResultCollection = {
  facets: FacetScanWarning[];
};

export type FacetScanStateResult = {
  facets: FacetScanResult[];
  facetCount: number;
};

export type SelectorExportIssue = {
  facetName: string;
  path: string;
  missingExports: string[];
  extraExports: string[];
};

export type SelectorOwner = {
  facetName: string;
  path: string;
  functionName: string;
  signature: string;
};

export type SelectorCollision = {
  selector: string;
  owners: SelectorOwner[];
};

export type SelectorCollisionDeps = {
  hashing: IHashingAdapter;
};

export type StorageLayoutInfo = {
  slot: string;
  layout: string[];
  source: "erc8042" | "slot-assignment";
  structName: string | null;
};

export type IdentifierCollisionOwner = {
  facetName: string;
  path: string;
  slot: string;
  layout: string[];
  source: StorageLayoutInfo["source"];
  structName: string | null;
};

export type IdentifierCollision = {
  identifier: string;
  owners: IdentifierCollisionOwner[];
};

export type SelectorExportValidationResult = {
  checkedFacets: number;
  issues: SelectorExportIssue[];
};

export type SelectorCollisionValidationResult = {
  checkedFacets: number;
  collisions: SelectorCollision[];
};

export type IdentifierCollisionValidationResult = {
  checkedFacets: number;
  collisions: IdentifierCollision[];
};

export type FacetScanWarning = {
  facetName: string;
  path: string;
  warnings: string[];
};
