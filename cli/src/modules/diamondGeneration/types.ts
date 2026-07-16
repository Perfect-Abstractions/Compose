import { ConstructorEntry, Erc165Entry } from "../config/types";

export type DiamondImport = {
  alias: string;
  path: string;
  style: "alias" | "named";
};

export type DiamondGenerationFile = {
  source: string;
  target: string;
};

export type DiamondGenerationModel = {
  contractName: string;
  solidityPragma: string;
  outputPath: string;
  imports: DiamondImport[];
  constructorEntries: ConstructorEntry[];
  erc165Registrations: Erc165Entry[];
  files: DiamondGenerationFile[];
};
