import type { ComposeContext, ModuleState } from "../context/types";
import type { IBytecodeValidatorAdapter } from "../adapters/IBytecodeValidatorAdapter/interface";
import type { IRPCAdapter } from "../adapters/IRPCAdapter/interface";
import { BytecodeValidationModule } from "../modules/bytecodeValidation/module";
import { DependencyKey } from "../resolver/dependencyKey";
import { DependencyResolver } from "../resolver/dependencyResolver";

function composeError(error: unknown) {
  return {
    code: typeof error === "object" && error && "code" in error
      ? String(error.code)
      : "BYTECODE_VALIDATION_FAILED",
    message: error instanceof Error ? error.message : "Bytecode validation failed.",
    nativeError: error,
  };
}

/** Child pipeline for one diamond deployment on one chain. */
export const BytecodeValidationPipeline = {
  async execute(ctx: ComposeContext): Promise<ComposeContext> {
    try {
      const dependencies = await DependencyResolver.resolve([
        {
          key: DependencyKey.RPC,
          params: {
            chainKey: ctx.param.chainKey,
            projectRoot: String(ctx.param.projectRoot),
          },
        },
        { key: DependencyKey.BytecodeValidator },
      ]);
      const rpc = dependencies[DependencyKey.RPC] as IRPCAdapter | undefined;
      const validator = dependencies[DependencyKey.BytecodeValidator] as IBytecodeValidatorAdapter | undefined;
      if (!rpc || !validator) throw new Error("Bytecode validation dependencies were not resolved.");

      ctx = await BytecodeValidationModule.validateDeployment(ctx, { rpc, validator });
      const state = ctx.state.bytecodeDeploymentValidation as ModuleState;
      if (!state.success) {
        ctx.status = {
          success: false,
          stopped: true,
          failedAt: "bytecodeDeploymentValidation",
          error: state.error,
        };
      }
      return ctx;
    } catch (error) {
      const resolvedError = composeError(error);
      ctx.state.bytecodeDeploymentValidation = {
        success: false,
        result: null,
        error: resolvedError,
      };
      ctx.status = {
        success: false,
        stopped: true,
        failedAt: "bytecodeDeploymentValidation",
        error: resolvedError,
      };
      return ctx;
    }
  },
};
