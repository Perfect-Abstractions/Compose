import { validateStorage } from "compose-bytecode-validator";
import type { StorageLocation, StorageValidationReport } from "compose-bytecode-validator/dist/evmole.js";
import type {
  BytecodeValidationInput,
  BytecodeValidationReport,
  IBytecodeValidatorAdapter,
} from "./interface";

const PLAIN_BYTE_ARRAY = /Plain\(\[([\d,\s]+)\]\)/g;

export function formatSymbolicStoragePath(path: string): string {
  return path.replace(PLAIN_BYTE_ARRAY, (match, values: string) => {
    const bytes = values.split(",").map((value) => Number(value.trim()));
    if (bytes.length !== 32 || bytes.some((byte) => !Number.isInteger(byte) || byte < 0 || byte > 255)) {
      return match;
    }
    return `Plain(0x${bytes.map((byte) => byte.toString(16).padStart(2, "0")).join("")})`;
  });
}

function normalizeLocation(location: StorageLocation): StorageLocation {
  return {
    ...location,
    symbolicPath: formatSymbolicStoragePath(location.symbolicPath),
  };
}

function normalizeReport(report: StorageValidationReport): BytecodeValidationReport {
  return {
    collisions: report.collisions.map((collision) => ({
      ...collision,
      location: normalizeLocation(collision.location),
    })),
    validatedVariables: report.validatedVariables.map((variable) => ({
      ...variable,
      location: normalizeLocation(variable.location),
    })),
    uncertainScopes: report.uncertainScopes.map((scope) => ({
      ...scope,
      location: normalizeLocation(scope.location),
    })),
    diagnostics: report.diagnostics.map((diagnostic) => ({
      ...diagnostic,
      symbolicPath: formatSymbolicStoragePath(diagnostic.symbolicPath),
    })),
    delegatecallWarnings: report.delegatecallWarnings,
  };
}

export const BytecodeValidatorAdapter: IBytecodeValidatorAdapter = {
  validate(input: BytecodeValidationInput): BytecodeValidationReport {
    return normalizeReport(validateStorage(input));
  },
};
