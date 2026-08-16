import { ComposeContext } from "../../context/types";

/** Options passed to adapter config writing. */
export type ConfigOptions = {
  compilerVersion: string;
  projectName: string;
  installDeps: boolean;
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
}
