import { ComposeContext } from "../../context/types";

/** Options passed to adapter config writing. */
export type ConfigOptions = {
  compilerVersion: string;
  projectName: string;
  installDeps: boolean;
};

/** Interface for framework-specific project scaffolding adapters. */
export interface IFrameworkAdapter {
  /** Resolve the framework's Solidity source root inside the generated project. */
  getContractSourceRoot(projectRoot: string): string;

  /** Resolve the framework's deploy script root inside the generated project. */
  getScriptRoot(projectRoot: string): string;

  /** Resolve the framework's test root inside the generated project. */
  getTestRoot(projectRoot: string): string;

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
}
