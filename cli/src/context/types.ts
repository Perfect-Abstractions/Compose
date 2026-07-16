export type ComposeError = {
  code: string;
  message: string;
  nativeError: unknown | null;
};

export type ModuleState<T = unknown> = {
  success: boolean;
  result: T | null;
  error: ComposeError | null;
};

export type ExecutionStatus = {
  success: boolean;
  stopped: boolean;
  failedAt: string | null;
  error: ComposeError | null;
};

export type ChildPipelineState = {
  success: boolean;
  state: Record<string, ModuleState>;
  status: ExecutionStatus;
};

export type ComposeContext = {
  param: Record<string, unknown>;
  config: Record<string, unknown>;
  state: Record<string, ModuleState | ChildPipelineState>;
  status: ExecutionStatus;
};
