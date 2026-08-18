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
  hasExportSelectorsFunction?: boolean;
  missingExports: string[];
  extraExports: string[];
  storageLayouts: StorageLayoutInfo[];
  warnings: string[];
};

export type FacetScanResultCollection = {
  facets: FacetScanResult[];
};

export type FacetReference = {
  contractName: string;
  sourcePath: string;
};

export type ResolvedFacetSource = FacetReference;

export type ResolvedFacetSourceResult = {
  sources: ResolvedFacetSource[];
};

export type FacetScanStateResult = {
  facets: FacetScanResult[];
  facetCount: number;
};

export type SelectorExportIssue = {
  facetName: string;
  path: string;
  missingExportSelectorsFunction: boolean;
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
  diamondName?: string;
};

export type DiamondValidationScope = {
  diamondName: string;
  facets: FacetReference[];
};

export type SelectorCollisionDeps = {
  hashing: IHashingAdapter;
  scopes?: DiamondValidationScope[];
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

export type VirtualStorageLayoutKind = "normal" | "immutable";

export type VirtualStorageLayoutSource =
  | "erc8042"
  | "erc7201"
  | "slot-assignment"
  | "implicit-state";

export type VirtualStorageLayoutRecord = {
  id: string;
  virtualPath: string;
  kind: VirtualStorageLayoutKind;
  codeWidth: 1;
  layout: string[];
  serializedLayout: string[];
  slots: number[][];
  source: VirtualStorageLayoutSource;
  sourceName: string;
  contractName: string;
  structName: string | null;
  diamondName?: string;
};

export type VirtualStorageLayoutWarning = {
  sourceName: string;
  message: string;
  diamondName?: string;
};

export type VirtualStorageLayoutCollision = {
  id: string;
  virtualPath: string;
  reason: string;
  records: VirtualStorageLayoutRecord[];
  diamondName?: string;
};

export type VirtualStorageLayoutResult = {
  records: VirtualStorageLayoutRecord[];
  warnings: VirtualStorageLayoutWarning[];
  collisions: VirtualStorageLayoutCollision[];
};
