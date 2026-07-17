export type PromptContext = {
  clearPromptOnDone?: boolean;
};

export type PromptApi = {
  checkbox: <Value>(
    config: {
      message: string;
      choices: readonly { name: string; value: Value; checked?: boolean }[];
      theme?: {
        prefix?: string | { idle?: string; done?: string };
        icon?: {
          checked?: string;
          unchecked?: string;
          cursor?: string;
          disabledChecked?: string;
          disabledUnchecked?: string;
        };
        style?: {
          keysHelpTip?: (keys: [key: string, action: string][]) => string | undefined;
        };
      };
    },
    context?: PromptContext,
  ) => Promise<Value[]>;
  select: <Value>(
    config: {
      message: string;
      choices: readonly { name: string; value: Value }[];
      default?: Value;
      theme?: {
        prefix?: string | { idle?: string; done?: string };
        icon?: {
          cursor?: string;
        };
        style?: {
          keysHelpTip?: (keys: [key: string, action: string][]) => string | undefined;
        };
      };
    },
    context?: PromptContext,
  ) => Promise<Value>;
  input: (config: {
    message: string;
    default?: string;
    validate?: (value: string) => boolean | string | Promise<boolean | string>;
    theme?: {
      prefix?: string | { idle?: string; done?: string };
    };
  }, context?: PromptContext) => Promise<string>;
  confirm: (config: {
    message: string;
    default?: boolean;
    theme?: {
      prefix?: string | { idle?: string; done?: string };
    };
  }, context?: PromptContext) => Promise<boolean>;
};

export type InitOptions = {
  projectName: string;
  base: string;
  libraries: string[];
  extensions: string[];
  ownership: string;
  ownershipExtensions: string[];
  accessControl: string[];
  accessControlExtensions: string[];
  framework: string;
  outDir: string;
  installDeps: boolean;
  yes: boolean;
};

export type AccessFlagSelection = {
  selectedOwnership: string[];
  selectedRoleAccess: string[];
  selectedOwnershipExtensions: string[];
  selectedRoleAccessExtensions: string[];
  selectedAccess: string[];
  selectedAccessExtensions: string[];
};

export type FrameworkDependencies = {
  deps: { name: string; version: string }[];
  packageType: string;
};
