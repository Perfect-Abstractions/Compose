import type { Address } from "viem";
import type { BytecodeValidationReport } from "../../adapters/IBytecodeValidatorAdapter/interface";

export type FacetBytecodeValidationResult = {
  address: Address;
  report: BytecodeValidationReport | null;
  uncertain: string | null;
  error: string | null;
};

export type DeploymentBytecodeValidationResult = {
  diamondName: string;
  chainKey: string;
  diamondAddress: Address;
  blockNumber: bigint;
  complete: boolean;
  introspectionError: string | null;
  facets: FacetBytecodeValidationResult[];
};

export type BytecodeValidationSummary = {
  skipped: boolean;
  complete: boolean;
  deployments: DeploymentBytecodeValidationResult[];
  failures: Array<{
    diamondName: string;
    chainKey: string;
    diamondAddress: string;
    message: string;
  }>;
};
