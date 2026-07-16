import { ComposeContext, ModuleState } from "../../context/types";
import {
  FacetScanStateResult,
  FacetScanResultCollection,
  SelectorExportValidationResult,
  SelectorCollisionValidationResult,
  IdentifierCollisionValidationResult,
} from "./types";

/**
 * Extracts the facet scan result from the compose context state.
 *
 * @param ctx - The compose context with facet scan state.
 * @returns The facet scan result, or null if not yet populated.
 */
export function getFacetScanResult(ctx: ComposeContext): FacetScanStateResult | null {
  const state = ctx.state.facetScan as ModuleState<FacetScanStateResult> | undefined;
  return state?.result ?? null;
}

/**
 * Returns the full facet scan module state from the compose context.
 *
 * @param ctx - The compose context.
 * @returns The facet scan module state, or null if not yet populated.
 */
export function getFacetScanState(ctx: ComposeContext): ModuleState<FacetScanResultCollection> | null {
  return (ctx.state.facetScan as ModuleState<FacetScanResultCollection> | undefined) ?? null;
}

/**
 * Returns the selector export validation module state from the compose context.
 *
 * @param ctx - The compose context.
 * @returns The validation state, or null if not yet populated.
 */
export function getSelectorExportValidationState(
  ctx: ComposeContext,
): ModuleState<SelectorExportValidationResult> | null {
  return (ctx.state.validationSelectorExports as ModuleState<SelectorExportValidationResult> | undefined) ?? null;
}

/**
 * Returns the selector collision validation module state from the compose context.
 *
 * @param ctx - The compose context.
 * @returns The validation state, or null if not yet populated.
 */
export function getSelectorCollisionValidationState(
  ctx: ComposeContext,
): ModuleState<SelectorCollisionValidationResult> | null {
  return (
    ctx.state.validationSelectorCollisions as ModuleState<SelectorCollisionValidationResult> | undefined
  ) ?? null;
}

/**
 * Returns the identifier collision validation module state from the compose context.
 *
 * @param ctx - The compose context.
 * @returns The validation state, or null if not yet populated.
 */
export function getIdentifierCollisionValidationState(
  ctx: ComposeContext,
): ModuleState<IdentifierCollisionValidationResult> | null {
  return (
    ctx.state.validationIdentifierCollisions as ModuleState<IdentifierCollisionValidationResult> | undefined
  ) ?? null;
}
