import { ComposeContext } from "../../context/types";
import type { Hex } from "viem";
import type {
  AccountAddressResolution,
  AccountResolutionOptions,
  BroadcastTransaction,
  ConfigOptions,
  DeployCommand,
  DeployCommandOptions,
  DeploySignerOptions,
  DeployToolbox,
  FrameworkCommand,
  SignerAddressOptions,
  SolidityAstSource,
  TestCommandOptions,
} from "./types";

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
   * Optional: makes package-sourced facets part of the framework build before a
   * validating compile. Hardhat lists them in `npmFilesToBuild`; resolves to a
   * revert closure, or null when nothing changed. Foundry omits it (its compile
   * takes explicit source paths, so package facets already build).
   */
  ensurePackageFacetsCompilable?(
    projectRoot: string,
    packageSpecifiers: string[],
  ): Promise<(() => Promise<void>) | null>;

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

  /** Whether Compose can import keys into this framework's native keystore. */
  readonly supportsAccountImport: boolean;

  /** Read a native account's address without unlocking or prompting. */
  readAccountAddress(
    projectRoot: string,
    accountName: string,
  ): Promise<AccountAddressResolution>;

  /** Resolve a native account's address, optionally unlocking it. */
  resolveAccountAddress(
    projectRoot: string,
    accountName: string,
    options?: AccountResolutionOptions,
  ): Promise<AccountAddressResolution>;

  /** List the addresses the framework will use to sign on a chain. */
  listSignerAddresses(options: SignerAddressOptions): Promise<string[]>;

  /**
   * Resolve the signer a deploy command will use without signing anything.
   * Returns null when the framework cannot expose the selected signer.
   */
  resolveDeploySigner(options: DeploySignerOptions): Promise<Hex | null>;

  /** Import a key interactively into the framework keystore and return its address. */
  importAccount(
    projectRoot: string,
    accountName: string,
  ): Promise<string | null>;

  /** Assert that the project uses a framework version Compose supports. */
  assertSupportedProject(projectRoot: string): void;

  /**
   * Detect the contract interaction toolbox used by the framework.
   * Returns null for frameworks without a JavaScript toolbox.
   */
  getDeployToolbox(projectRoot: string): Promise<DeployToolbox | null>;

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
