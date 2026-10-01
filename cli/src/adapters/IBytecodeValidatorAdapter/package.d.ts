declare module "compose-bytecode-validator" {
  import type { StorageValidationReport, VirtualStorageLayout } from "compose-bytecode-validator/dist/evmole.js";

  export function validateStorage(input: {
    bytecode: string;
    virtualStorageLayout: VirtualStorageLayout;
  }): StorageValidationReport;
}
