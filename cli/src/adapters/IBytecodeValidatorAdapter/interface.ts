import type { Hex } from "viem";

export type BytecodeStorageLocation = {
  slot: string;
  offset: number;
  selector: string;
  pc?: number;
  symbolicPath: string;
};

export type BytecodeStorageCollision = {
  location: BytecodeStorageLocation;
  virtualPath: string;
  sourceNames?: string[];
  expectedType: string;
  observedType: string;
  reason: string;
};

export type BytecodeValidatedVariable = {
  location: BytecodeStorageLocation;
  virtualPath: string;
  sourceNames?: string[];
  expectedType: string;
  observedType: string;
};

export type BytecodeUncertainScope = {
  location: BytecodeStorageLocation;
  virtualPath?: string;
  sourceNames?: string[];
  reason: string;
};

export type BytecodeStorageDiagnostic = {
  selector: string;
  pc?: number;
  symbolicPath: string;
  message: string;
};

export type BytecodeDelegateCallWarning = {
  callerSelector: string;
  pc: number;
  target: string;
  selector?: string;
  reason: string;
};

export type BytecodeValidationReport = {
  collisions: BytecodeStorageCollision[];
  validatedVariables: BytecodeValidatedVariable[];
  uncertainScopes: BytecodeUncertainScope[];
  diagnostics: BytecodeStorageDiagnostic[];
  delegatecallWarnings: BytecodeDelegateCallWarning[];
};

export type BytecodeVirtualStorageRecord = {
  id: string;
  virtualPath: string;
  parentVirtualPath?: string;
  kind: "normal" | "immutable";
  codeWidth: number;
  layout: string[];
  serializedLayout: string[];
  slots: number[][];
  source: "erc8042" | "erc7201" | "slot-assignment" | "implicit-state";
  sourceName: string;
  contractName: string;
  structName?: string;
  diamondName?: string;
};

export type BytecodeValidationInput = {
  bytecode: Hex;
  virtualStorageLayout: { records: BytecodeVirtualStorageRecord[] };
};

/** Stable CLI boundary around the external WASM validator package. */
export interface IBytecodeValidatorAdapter {
  validate(input: BytecodeValidationInput): BytecodeValidationReport;
}
