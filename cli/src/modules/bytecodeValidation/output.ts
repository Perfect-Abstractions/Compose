import type { ComposeContext, ModuleState } from "../../context/types";
import type { BytecodeUncertainScope } from "../../adapters/IBytecodeValidatorAdapter/interface";
import { red, yellow } from "../../utils/terminal";
import type { BytecodeValidationSummary } from "./types";

type OutputWriter = (message: string) => void;

function printAffectedSources(sourceNames: string[] | undefined, write: OutputWriter): void {
  if (!sourceNames?.length) return;
  write("  Affected:");
  for (const sourceName of sourceNames) write(`    - ${sourceName}`);
}

function deduplicateUncertainScopes(scopes: BytecodeUncertainScope[]): BytecodeUncertainScope[] {
  const seen = new Set<string>();
  return scopes.filter((scope) => {
    const displayedPath = scope.virtualPath ?? scope.location.symbolicPath;
    const sources = [...(scope.sourceNames ?? [])].sort();
    const key = JSON.stringify([scope.reason, displayedPath, sources]);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/** Prints deployed-bytecode collisions and scoped warnings. */
export function showBytecodeValidationReport(ctx: ComposeContext): void {
  const state = ctx.state.bytecodeValidation as ModuleState<BytecodeValidationSummary> | undefined;
  if (!state || state.result?.skipped) return;

  if (!state.success && !state.result) {
    console.error(red("\nBytecode validation failed"));
    console.error(red(state.error?.message ?? "Bytecode validation failed."));
    return;
  }

  for (const failure of state.result?.failures ?? []) {
    console.error(red("\nBytecode validation failed"));
    console.error(red(`  ${failure.message}`));
    console.error(`${failure.diamondName} / ${failure.chainKey}`);
    console.error(`  ${failure.diamondAddress}`);
  }

  for (const deployment of state.result?.deployments ?? []) {
    const scope = `${deployment.diamondName} / ${deployment.chainKey}`;
    if (deployment.introspectionError) {
      console.error(red("\nDiamond introspection error"));
      console.error(red(`  ${deployment.introspectionError}`));
      console.error(`${scope} / ${deployment.diamondAddress}`);
      continue;
    }
    for (const facet of deployment.facets) {
      if (facet.error) {
        console.error(red("\nBytecode validation failed"));
        console.error(red(`  ${facet.error}`));
        console.error(`${scope} / ${facet.address}`);
        continue;
      }
      if (facet.uncertain) {
        console.warn(yellow(`\nBytecode validation incomplete`));
        console.warn(yellow(`  ${facet.uncertain}`));
        console.warn(`${scope} / ${facet.address}`);
        continue;
      }
      if (!facet.report) continue;

      for (const collision of facet.report.collisions) {
        console.error(red("\nBytecode validation failed"));
        console.error(red(`  ${collision.reason}`));
        console.error(`${scope} / ${facet.address}`);
        console.error(`  ${collision.virtualPath}`);
        printAffectedSources(collision.sourceNames, (message) => console.error(message));
        console.error(`  Expected: ${collision.expectedType}`);
        console.error(`  Observed: ${collision.observedType}`);
        console.error(`  Selector: ${collision.location.selector}`);
        if (collision.location.pc !== undefined) console.error(`  PC: ${collision.location.pc}`);
      }

      for (const uncertain of deduplicateUncertainScopes(facet.report.uncertainScopes)) {
        console.warn(yellow("\nBytecode validation warning"));
        console.warn(yellow(`  ${uncertain.reason}`));
        console.warn(`${scope} / ${facet.address}`);
        console.warn(`  ${uncertain.virtualPath ?? uncertain.location.symbolicPath}`);
        printAffectedSources(uncertain.sourceNames, (message) => console.warn(message));
      }
      for (const diagnostic of facet.report.diagnostics) {
        console.warn(yellow("\nBytecode validation warning"));
        console.warn(yellow(`  ${diagnostic.message}`));
        console.warn(`${scope} / ${facet.address}`);
        console.warn(`  ${diagnostic.symbolicPath}`);
      }
      for (const warning of facet.report.delegatecallWarnings) {
        console.warn(yellow("\nBytecode validation warning"));
        console.warn(yellow(`  delegatecall at PC ${warning.pc}: ${warning.reason}`));
        console.warn(`${scope} / ${facet.address}`);
      }
    }
  }
}
