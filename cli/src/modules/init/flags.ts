import { uniqueStrings, splitCommaSeparated } from "../../utils/strings";
import { AccessFlagSelection } from "./types";

/**
 * Resolves grouped access flags from raw CLI parameters into a structured selection.
 * Ensures at most one ownership base is selected.
 *
 * @param param - Raw CLI parameter record containing access-related flags.
 * @returns The resolved access flag selection with deduplicated values.
 * @throws {Error} If more than one ownership base is provided.
 */
export function resolveAccessFlags(param: Record<string, unknown>): AccessFlagSelection {
  const ownership = splitCommaSeparated(param.ownership);
  if (ownership.length > 1) {
    throw new Error("--ownership accepts only one ownership base.");
  }

  return {
    selectedOwnership: ownership,
    selectedRoleAccess: splitCommaSeparated(param.accessControl),
    selectedOwnershipExtensions: splitCommaSeparated(param.ownershipExtensions),
    selectedRoleAccessExtensions: splitCommaSeparated(param.accessControlExtensions),
    selectedAccess: uniqueStrings([
      ...ownership,
      ...splitCommaSeparated(param.accessControl),
    ]),
    selectedAccessExtensions: uniqueStrings([
      ...splitCommaSeparated(param.ownershipExtensions),
      ...splitCommaSeparated(param.accessControlExtensions),
    ]),
  };
}

