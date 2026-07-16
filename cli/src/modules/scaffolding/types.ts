import { FacetEntry } from "../config/types";
import { SolidityFunctionInfo } from "../../utils/solidityText";

export type SeedFile = {
  source: string;
  target: string;
};

export type SelectedFacetSource =
  | "diamond-required"
  | "diamond-optional"
  | "library-required"
  | "base-required"
  | "access-required"
  | "library-optional"
  | "extension"
  | "access-extension";

export type SelectedFacet = {
  name: string;
  source: SelectedFacetSource;
  entry: FacetEntry;
};

export type StorageLayoutInfo = {
  slot: string;
  layout: string[];
  source: "erc8042" | "slot-assignment";
  structName: string | null;
};

export type FacetScanResult = {
  facetName: string;
  source: SelectedFacetSource;
  path: string;
  contractName: string | null;
  functions: SolidityFunctionInfo[];
  exportedSelectors: string[];
  missingExports: string[];
  extraExports: string[];
  storageLayouts: StorageLayoutInfo[];
  warnings: string[];
};

export type FacetOrigin = "local" | "package";

export type ScaffoldMapEntry = {
  facetName: string;
  contractName: string;
  targetPath: string;
  origin: FacetOrigin;
};
