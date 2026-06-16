type ComposeError = {
  code: string;
  message: string;
  nativeError: unknown | null;
};

type ModuleState<T = unknown> = {
  success: boolean;
  result: T | null;
  error: ComposeError | null;
};

type ExecutionStatus = {
  success: boolean;
  stopped: boolean;
  failedAt: string | null;
  error: ComposeError | null;
};

type ComposeContext = {
  param: Record<string, unknown>;
  config: Record<string, unknown>;
  state: Record<string, ModuleState>;
  status: ExecutionStatus;
};

interface DiamondInspectAdapter {
  facetAddresses(address: string): Promise<string[]>;
}

type DiamondInspectDeps = {
  diamondInspect: DiamondInspectAdapter;
};

const DiamondInspect = {
  async readFacetAddresses(
    ctx: ComposeContext,
    { diamondInspect }: DiamondInspectDeps
  ): Promise<ComposeContext> {
    const address = ctx.param.address as string;
    const facetAddresses = await diamondInspect.facetAddresses(address);

    ctx.state.diamondInspect = {
      success: true,
      result: {
        facetAddresses,
      },
      error: null,
    };

    return ctx;
  },
};

enum DependencyKey {
  DiamondInspect = "diamondInspect",
}

const DependencyResolver = {
  async resolve(_requests: { key: DependencyKey; params?: unknown }[]) {
    return {
      diamondInspect: {} as DiamondInspectAdapter,
    };
  },
};

export async function validatePipeline(
  ctx: ComposeContext
): Promise<ComposeContext> {
  const deps = (await DependencyResolver.resolve([
    {
      key: DependencyKey.DiamondInspect,
      params: {
        chain: ctx.param.chain,
      },
    },
  ])) as DiamondInspectDeps;

  ctx = await DiamondInspect.readFacetAddresses(ctx, deps);

  return ctx;
}
