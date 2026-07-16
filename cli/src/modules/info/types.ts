export type FacetInfo = {
  name: string;
  source: "local" | "package" | "registry";
  contract: string;
  package?: string;
  selectors: string[];
  storageSlots: StorageSlotInfo[];
};

export type StorageSlotInfo = {
  slot: string;
  layout: string[];
  source: "erc8042" | "slot-assignment";
  structName: string | null;
};

export type DiamondInfo = {
  name: string;
  contract: string;
  facets: FacetInfo[];
};

export type ComposeProjectInfo = {
  project: string;
  composeVersion: string;
  framework: string;
  diamonds: DiamondInfo[];
  warnings: string[];
};

export type InfoState = {
  composeJsonPath: string;
  composeJson: Record<string, unknown>;
  projectInfo: ComposeProjectInfo;
};
