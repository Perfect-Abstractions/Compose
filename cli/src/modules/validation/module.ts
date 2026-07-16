import { ComposeContext } from "../../context/types";
import { SelectorCollisionDeps } from "./types";
import {
  findIdentifierCollisions,
  findSelectorCollisions,
  findSelectorExportIssues,
} from "./validators";
import {
  getFacetScanResult,
  getFacetScanState,
  getIdentifierCollisionValidationState,
  getSelectorCollisionValidationState,
  getSelectorExportValidationState,
} from "./state";
import { showReport } from "./output";

/**
 * Validates facet scans for selector export correctness and collision-free layouts.
 *
 * Provides three validation steps that run sequentially in the init pipelines:
 * 1. Selector export validation — ensures every public/external function is declared in `exportSelectors()`.
 * 2. Selector collision detection — detects duplicate 4-byte selectors across facets.
 * 3. Identifier collision detection — detects incompatible storage layouts for the same storage slot.
 *
 * Each step stores its result as a `ModuleState` in `ctx.state` and sets
 * `success: false` when issues are found.
 */
export const ValidationModule = {
  showReport,
  getFacetScanState,
  getSelectorExportValidationState,
  getSelectorCollisionValidationState,
  getIdentifierCollisionValidationState,
  
  /**
   * Returns true when selector export validation has found blocking issues.
   *
   * Keeps validation state reads inside the validation module boundary.
   */
  hasSelectorExportFailure(ctx: ComposeContext): boolean {
    const state = getSelectorExportValidationState(ctx);
    return Boolean(state && !state.success);
  },

  /**
   * Returns true when selector collision validation has found blocking issues.
   *
   * Keeps validation state reads inside the validation module boundary.
   */
  hasSelectorCollisionFailure(ctx: ComposeContext): boolean {
    const state = getSelectorCollisionValidationState(ctx);
    return Boolean(state && !state.success);
  },

  /**
   * Returns true when identifier collision validation has found blocking issues.
   *
   * Keeps validation state reads inside the validation module boundary.
   */
  hasIdentifierCollisionFailure(ctx: ComposeContext): boolean {
    const state = getIdentifierCollisionValidationState(ctx);
    return Boolean(state && !state.success);
  },

  /**
   * Returns true when any validation stage has produced a blocking failure.
   *
   * Pipelines can use this for orchestration without importing validation helpers.
   */
  hasBlockingFailure(ctx: ComposeContext): boolean {
    return (
      ValidationModule.hasSelectorExportFailure(ctx) ||
      ValidationModule.hasSelectorCollisionFailure(ctx) ||
      ValidationModule.hasIdentifierCollisionFailure(ctx)
    );
  },

  /**
   * Validates that every public/external function is exported by `exportSelectors()`.
   *
   * Requires `ctx.state.facetScan` to have been populated by
   * {@link ScaffoldingModule.scanSelectedFacets}. For each facet, checks that
   * every public/external function name appears in the facet's exported
   * selector list and that no extra names are declared.
   *
   * @param ctx - The compose context with facet scan results.
   * @returns The context with `ctx.state.validationSelectorExports` populated.
   */
  async validateSelectorExports(ctx: ComposeContext): Promise<ComposeContext> {
    const facetScan = getFacetScanResult(ctx);

    if (!facetScan) {
      ctx.state.validationSelectorExports = {
        success: false,
        result: null,
        error: {
          code: "FACET_SCAN_MISSING",
          message: "Facet scan must run before selector export validation.",
          nativeError: null,
        },
      };
      return ctx;
    }

    const issues = findSelectorExportIssues(facetScan.facets);
    const success = issues.length === 0;

    ctx.state.validationSelectorExports = {
      success,
      result: {
        checkedFacets: facetScan.facetCount,
        issues,
      },
      error: success
        ? null
        : {
            code: "SELECTOR_EXPORT_INVALID",
            message: "One or more selected facets do not export all intended selectors.",
            nativeError: null,
          },
    };

    return ctx;
  },

  /**
   * Detects duplicate 4-byte selectors across selected exported facet functions.
   *
   * Uses the provided hashing adapter to compute 4-byte selectors, then groups
   * facets by selector to find collisions. Requires `ctx.state.facetScan` to
   * have been populated first.
   *
   * @param ctx - The compose context with facet scan results.
   * @param deps - Dependencies: an `IHashingAdapter` for keccak256 computation.
   * @returns The context with `ctx.state.validationSelectorCollisions` populated.
   */
  async detectSelectorCollisions(
    ctx: ComposeContext,
    { hashing }: SelectorCollisionDeps,
  ): Promise<ComposeContext> {
    const facetScan = getFacetScanResult(ctx);

    if (!facetScan) {
      ctx.state.validationSelectorCollisions = {
        success: false,
        result: null,
        error: {
          code: "FACET_SCAN_MISSING",
          message: "Facet scan must run before selector collision detection.",
          nativeError: null,
        },
      };
      return ctx;
    }

    const collisions = findSelectorCollisions(facetScan.facets, hashing);
    const success = collisions.length === 0;

    ctx.state.validationSelectorCollisions = {
      success,
      result: {
        checkedFacets: facetScan.facetCount,
        collisions,
      },
      error: success
        ? null
        : {
            code: "SELECTOR_COLLISION_DETECTED",
            message: "Two or more selected facets export the same function selector.",
            nativeError: null,
          },
    };

    return ctx;
  },

  /**
   * Detects incompatible storage layouts sharing the same storage identifier.
   *
   * Groups storage layouts by slot identifier and checks whether all layouts
   * for a given slot are prefix-compatible (safe extensions). Requires
   * `ctx.state.facetScan` to have been populated first.
   *
   * @param ctx - The compose context with facet scan results.
   * @returns The context with `ctx.state.validationIdentifierCollisions` populated.
   */
  async detectIdentifierCollisions(ctx: ComposeContext): Promise<ComposeContext> {
    const facetScan = getFacetScanResult(ctx);

    if (!facetScan) {
      ctx.state.validationIdentifierCollisions = {
        success: false,
        result: null,
        error: {
          code: "FACET_SCAN_MISSING",
          message: "Facet scan must run before identifier collision detection.",
          nativeError: null,
        },
      };
      return ctx;
    }

    const collisions = findIdentifierCollisions(facetScan.facets);
    const success = collisions.length === 0;

    ctx.state.validationIdentifierCollisions = {
      success,
      result: {
        checkedFacets: facetScan.facetCount,
        collisions,
      },
      error: success
        ? null
        : {
            code: "IDENTIFIER_COLLISION_DETECTED",
            message: "Two or more selected facets use incompatible storage layouts for the same identifier.",
            nativeError: null,
          },
    };

    return ctx;
  },
};
