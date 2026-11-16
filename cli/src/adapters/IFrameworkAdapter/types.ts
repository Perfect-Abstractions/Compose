/** Options passed to adapter config writing. */
export type ConfigOptions = {
  compilerVersion: string;
  projectName: string;
  installDeps: boolean;
};

/** Options for building the framework command that runs a managed deployment artifact. */
export type DeployCommandOptions = {
  /** Absolute project root the command runs in. */
  projectRoot: string;
  /** Absolute path of the reviewable managed deployment artifact. */
  scriptPath: string;
  /** Absolute path of a framework runner that invokes the reviewed artifact. */
  runnerPath?: string | null;
  /** Chain key as defined in compose.json. */
  chainKey: string;
  /** RPC endpoint for the target chain. */
  rpcUrl: string;
  /** Expected EVM chain ID for the target chain. */
  chainId: number;
  /** Whether the managed script is simulated locally or broadcast to the target. */
  mode: "simulate" | "broadcast";
  /** Target-chain block used as the fork point for simulations. */
  forkBlockNumber?: bigint;
  /** Optional Compose account selection mapped to a framework-native signer. */
  account?: { alias: string; address: string; foundryAccount?: string } | null;
  /** Extra arguments forwarded to the framework after `--`. */
  passthrough: string[];
};

/** Options for building the framework command that runs the project test suite. */
export type TestCommandOptions = {
  /** Absolute project root the command runs in. */
  projectRoot: string;
  /** Extra arguments forwarded to the framework after `--`. */
  passthrough: string[];
};

/** Contract interaction toolbox variants used by Compose's managed deploy scripts. */
export type DeployToolbox = "ethers" | "viem";

/** Result of reading or resolving a framework-native account reference. */
export type AccountAddressResolution = {
  /** Public address when it can be read or was resolved. */
  address: string | null;
  /** Whether a native account reference exists (for Foundry, a keystore file). */
  exists: boolean;
  /** Whether an existing account needs an interactive unlock to expose its address. */
  requiresUnlock: boolean;
};

/** Options for resolving a framework-native account. */
export type AccountResolutionOptions = {
  /** Whether the adapter may unlock an encrypted account. */
  allowUnlock?: boolean;
  /** Called immediately before the framework prompts for a password. */
  onUnlock?: () => void;
};

/** Options for listing the signers a framework will use for a chain. */
export type SignerAddressOptions = AccountResolutionOptions & {
  /** Absolute project root the framework command runs in. */
  projectRoot: string;
  /** Chain key as defined in compose.json. */
  chainKey: string;
  /** RPC endpoint for the target chain. */
  rpcUrl: string;
  /** Expected EVM chain ID for the target chain. */
  chainId: number;
  /** Foundry keystore name; ignored by frameworks without named accounts. */
  accountName?: string;
};

/** Options for resolving the signer a deployment command will use. */
export type DeploySignerOptions = {
  /** Absolute project root the framework command runs in. */
  projectRoot: string;
  /** Chain key as defined in compose.json. */
  chainKey: string;
  /** RPC endpoint for the target chain. */
  rpcUrl: string;
  /** Expected EVM chain ID for the target chain. */
  chainId: number;
  /** Optional Compose account selection mapped to a framework-native signer. */
  account?: { alias: string; address: string; foundryAccount?: string } | null;
  /** Framework arguments forwarded after `--`. */
  passthrough: string[];
};

/** A framework command ready to be executed. */
export type FrameworkCommand = {
  command: string;
  args: string[];
  /** Environment overrides for the spawned framework process. */
  env?: NodeJS.ProcessEnv;
};

/** A deploy command ready to be executed. */
export type DeployCommand = FrameworkCommand;

/** A contract deployment recorded by a framework broadcast. */
export type BroadcastTransaction = {
  contractName?: string | null;
  contractAddress?: string | null;
  txHash?: string | null;
  from?: string | null;
};

/** A Solidity source unit AST returned by a framework compiler. */
export type SolidityAstSource = {
  sourceName: string;
  ast: SoliditySourceUnitAst;
};

/** Minimal stable shape shared by Solidity compact AST source units. */
export type SoliditySourceUnitAst = {
  id: number;
  nodeType: "SourceUnit";
  src: string;
  absolutePath?: string;
  nodes?: unknown[];
  [key: string]: unknown;
};
