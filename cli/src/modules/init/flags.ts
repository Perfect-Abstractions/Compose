import { uniqueStrings, splitCommaSeparated } from "../../utils/strings";
import { AccessFlagSelection, UpgradeabilitySelection } from "./types";

/**
 * Resolves the upgradeability choice from CLI flags.
 *
 * Immutable is the default; `--upgradeable` opts in to the upgrade facet and
 * the owner coupling derived from it.
 *
 * @param param - Raw CLI parameter record containing upgradeability flags.
 * @returns The resolved upgradeability selection with explicitness tracking.
 * @throws {Error} If both `--upgradeable` and `--immutable` are provided.
 */
export function resolveUpgradeability(param: Record<string, unknown>): UpgradeabilitySelection {
  const upgradeable = param.upgradeable === true;
  const immutable = param.immutable === true;

  if (upgradeable && immutable) {
    throw new Error("Use either --upgradeable or --immutable, not both.");
  }

  return {
    upgradeable,
    explicit: upgradeable || immutable,
  };
}

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

