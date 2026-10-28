import { ComposeContext } from "../../context/types";
import type { Hex } from "viem";

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

/** Interface for framework-specific project scaffolding adapters. */
export interface IFrameworkAdapter {
  /** Resolve the framework's Solidity source root inside the generated project. */
  getContractSourceRoot(projectRoot: string): string;

  /** Resolve the framework's deploy script root inside the generated project. */
  getScriptRoot(projectRoot: string): string;

  /** Resolve the framework's test root inside the generated project. */
  getTestRoot(projectRoot: string): string;

  /** Resolve the framework's artifact output directory inside the generated project. */
  getArtifactDir(projectRoot: string): string;

  /** Compile the project using the framework's build tool. */
  compile(projectRoot: string): Promise<void>;

  /** Compile explicit Solidity entrypoints and return every unique source unit AST. */
  compileAst(ctx: ComposeContext, sourcePaths: string[]): Promise<SolidityAstSource[]>;

  /**
   * Resolve a catalog Solidity path to a readable local file.
   *
   * Package paths resolve from the CLI's own node_modules/@perfect-abstractions/compose/.
   * Local paths resolve from the CLI's src/templates/ directory.
   */
  resolveSoliditySourcePath(ctx: ComposeContext, sourcePath: string): Promise<string>;

  /**
   * Initialize the project scaffold (e.g., run `forge init`, create `package.json`).
   * Called before facet files are copied.
   */
  initProject(ctx: ComposeContext): Promise<void>;

  /**
   * Write framework-specific configuration files (e.g., foundry.toml, hardhat.config.ts).
   * Called after facets are copied.
   */
  writeConfig(ctx: ComposeContext, opts: ConfigOptions): Promise<void>;

  /** Resolve the path of the CLI-managed deployment artifact inside the project. */
  getManagedDeployScriptPath(projectRoot: string): string;

  /** Resolve an optional runtime runner separate from the reviewed deploy artifact. */
  getManagedDeployRunnerPath(projectRoot: string): string | null;

  /**
   * Resolve the path of the CLI-managed deploy result file inside the project.
   * Returns null for frameworks that record deployments through their broadcast.
   */
  getManagedDeployResultPath(projectRoot: string): string | null;

  /** Build the framework command that simulates or broadcasts the managed deployment artifact. */
  createDeployCommand(opts: DeployCommandOptions): DeployCommand;

  /** Build the framework command that executes the project test suite. */
  createTestCommand(opts: TestCommandOptions): FrameworkCommand;

  /**
   * Read compiled deployed bytecode for a contract from the framework's
   * local build artifacts. Returns undefined when no artifact is available.
   */
  readDeployedBytecode(
    projectRoot: string,
    sourcePath: string,
    contractName: string,
  ): Promise<Hex | undefined>;

  /**
   * Read the contract deployments recorded by a framework broadcast.
   * Returns an empty list for frameworks that report transactions elsewhere.
   */
  readBroadcastTransactions(
    projectRoot: string,
    scriptPath: string,
    chainId: number,
  ): Promise<BroadcastTransaction[]>;
}
