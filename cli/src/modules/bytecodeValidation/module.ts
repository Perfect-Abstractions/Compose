import { getAddress, type Address } from "viem";
import type {
  BytecodeValidationReport,
  IBytecodeValidatorAdapter,
} from "../../adapters/IBytecodeValidatorAdapter/interface";
import type { IRPCAdapter } from "../../adapters/IRPCAdapter/interface";
import type { ComposeContext, ModuleState } from "../../context/types";
import { DIAMOND_INSPECT_ABI } from "../inspect/diamondInspectAbi";
import type { VirtualStorageLayoutRecord } from "../validation/types";
import type {
  BytecodeValidationSummary,
  DeploymentBytecodeValidationResult,
} from "./types";

type DeploymentDependencies = {
  rpc: IRPCAdapter;
  validator: IBytecodeValidatorAdapter;
};

type InspectedFacet = {
  facet: Address;
  functionSelectors: `0x${string}`[];
};

function storageRecords(ctx: ComposeContext): VirtualStorageLayoutRecord[] {
  return (ctx.param.virtualStorageRecords as VirtualStorageLayoutRecord[] | undefined) ?? [];
}

function validatorRecords(records: VirtualStorageLayoutRecord[]) {
  return records.map((record) => ({
    ...record,
    parentVirtualPath: record.parentVirtualPath ?? undefined,
    structName: record.structName ?? undefined,
  }));
}

function sourceNamesForPath(
  virtualPath: string | undefined,
  records: VirtualStorageLayoutRecord[],
): string[] {
  if (!virtualPath) return [];
  const matches = records.filter((record) =>
    virtualPath === record.virtualPath || virtualPath.startsWith(`${record.virtualPath}.`));
  const longestPath = Math.max(0, ...matches.map((record) => record.virtualPath.length));
  return [...new Set(
    matches
      .filter((record) => record.virtualPath.length === longestPath)
      .map((record) => record.sourceName),
  )];
}

function addVslSourceNames(
  report: BytecodeValidationReport,
  records: VirtualStorageLayoutRecord[],
): BytecodeValidationReport {
  return {
    ...report,
    collisions: report.collisions.map((collision) => ({
      ...collision,
      sourceNames: sourceNamesForPath(collision.virtualPath, records),
    })),
    validatedVariables: report.validatedVariables.map((variable) => ({
      ...variable,
      sourceNames: sourceNamesForPath(variable.virtualPath, records),
    })),
    uncertainScopes: report.uncertainScopes.map((scope) => ({
      ...scope,
      sourceNames: sourceNamesForPath(scope.virtualPath, records),
    })),
  };
}

/** Validates all current facets of one deployed diamond at one pinned block. */
export const BytecodeValidationModule = {
  async validateDeployment(
    ctx: ComposeContext,
    dependencies: DeploymentDependencies,
  ): Promise<ComposeContext> {
    const diamondName = String(ctx.param.diamondName);
    const chainKey = String(ctx.param.chainKey);
    const diamondAddress = getAddress(String(ctx.param.diamondAddress));
    const blockNumber = await dependencies.rpc.getBlockNumber();
    let rawFacets: InspectedFacet[];
    try {
      rawFacets = await dependencies.rpc.readContract<InspectedFacet[]>({
        address: diamondAddress,
        abi: DIAMOND_INSPECT_ABI,
        functionName: "facets",
        blockNumber,
      }, { verifyCode: true });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Diamond introspection failed.";
      ctx.state.bytecodeDeploymentValidation = {
        success: true,
        result: {
          diamondName,
          chainKey,
          diamondAddress,
          blockNumber,
          complete: false,
          introspectionError: message,
          facets: [],
        },
        error: null,
      };
      return ctx;
    }
    const facetAddresses = [...new Set(rawFacets.map((facet) => getAddress(facet.facet)))];
    const records = validatorRecords(storageRecords(ctx));
    const facets = [];

    for (const address of facetAddresses) {
      try {
        const bytecode = await dependencies.rpc.getCode(address, blockNumber);
        if (!bytecode || bytecode === "0x") {
          facets.push({
            address,
            report: null,
            uncertain: `Runtime bytecode was unavailable at pinned block ${blockNumber}; this facet was not validated.`,
            error: null,
          });
          continue;
        }

        facets.push({
          address,
          report: addVslSourceNames(
            dependencies.validator.validate({
              bytecode,
              virtualStorageLayout: { records },
            }),
            storageRecords(ctx),
          ),
          uncertain: null,
          error: null,
        });
      } catch (error) {
        facets.push({
          address,
          report: null,
          uncertain: null,
          error: error instanceof Error ? error.message : "Facet bytecode validation failed.",
        });
      }
    }

    const result: DeploymentBytecodeValidationResult = {
      diamondName,
      chainKey,
      diamondAddress,
      blockNumber,
      complete: facets.every((facet) => facet.uncertain === null),
      introspectionError: null,
      facets,
    };
    const collisions = facets.flatMap((facet) => facet.report?.collisions ?? []);
    const facetErrors = facets.filter((facet) => facet.error);
    const success = collisions.length === 0 && facetErrors.length === 0;
    ctx.state.bytecodeDeploymentValidation = {
      success,
      result,
      error: success
        ? null
        : {
            code: collisions.length > 0
              ? "BYTECODE_STORAGE_COLLISION_DETECTED"
              : "BYTECODE_FACET_VALIDATION_FAILED",
            message: collisions.length > 0
              ? "Deployed facet bytecode contradicts the diamond storage layout."
              : "One or more deployed facets could not be validated.",
            nativeError: null,
          },
    };
    return ctx;
  },

  mergeDeployments(
    ctx: ComposeContext,
    children: ComposeContext[],
    skipped = false,
  ): ComposeContext {
    const deployments = children.map((child) =>
      child.state.bytecodeDeploymentValidation as ModuleState<DeploymentBytecodeValidationResult>);
    const failed = deployments.find((deployment) => !deployment.success);
    const result: BytecodeValidationSummary = {
      skipped,
      complete: deployments.every((deployment) => deployment.result?.complete !== false),
      deployments: deployments.flatMap((deployment) => deployment.result ? [deployment.result] : []),
      failures: children.flatMap((child, index) => {
        const deployment = deployments[index];
        if (deployment.success || deployment.result) return [];
        return [{
          diamondName: String(child.param.diamondName),
          chainKey: String(child.param.chainKey),
          diamondAddress: String(child.param.diamondAddress),
          message: deployment.error?.message ?? "Bytecode validation failed.",
        }];
      }),
    };
    ctx.state.bytecodeValidation = {
      success: !failed,
      result,
      error: failed?.error ?? null,
    };
    return ctx;
  },
};
