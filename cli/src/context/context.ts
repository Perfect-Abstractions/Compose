import { ComposeContext } from "./types";


export const Context = {
  // Create a fresh command context with empty params, config, state, and successful status.
  create(): ComposeContext {
    return {
      param: {},
      config: {},
      state: {},
      status: {
        success: true,
        stopped: false,
        failedAt: null,
        error: null,
      },
    };
  },
};
