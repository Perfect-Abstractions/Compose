export type Erc165Entry = {
  path: string;
  id: string;
  comments?: string[];
};

export type ConstructorEntry = {
  comments?: string[];
  code: string;
};

export type FacetEntry = {
  path: string;
  mod?: string;
  constructor?: ConstructorEntry[];
  erc165?: Erc165Entry;
};

export type BaseDefinition = {
  label: string;
  order?: number;
  visible?: boolean;
  access?: boolean;
  accessType?: "ownership" | "roles";
  pragma?: string;
  compilerVersion?: string;
  erc165?: Erc165Entry;
  required: Record<string, FacetEntry>;
  optional: Record<string, FacetEntry>;
};

export type BaseManifest = Record<string, BaseDefinition>;

export type BasesCatalog = {
  globals: {
    diamond?: BaseDefinition;
    libraries?: BaseDefinition;
    examples?: BaseDefinition;
  };
  features: Record<string, BaseDefinition>;
};

export type CatalogSelection = {
  selectedBaseKey: string;
  selectedBase: BaseDefinition;
  selectedGlobalLibraries: string[];
  selectedAccessBaseKeys: string[];
  selectedAccessBases: BaseDefinition[];
  selectedExtensions: string[];
  selectedAccessExtensions: string[];
  requiredFacets: Record<string, FacetEntry>;
  availableGlobalLibraryFacets: Record<string, FacetEntry>;
  availableExtensions: Record<string, FacetEntry>;
  availableAccessExtensions: Record<string, FacetEntry>;
};
