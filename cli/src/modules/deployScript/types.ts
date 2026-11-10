import type { Hex } from "viem";

/** Hardhat toolbox variants supported by the managed deploy script. */
export type ScriptToolbox = "ethers" | "viem";

/** One facet entry rendered into the managed deploy script. */
export type ScriptFacetEntry = {
  /** compose.json facet key, used in the result file. */
  name: string;
  contractName: string;
  importSpec: string;
  /** Unique camelCase local variable name for the deployed contract. */
  variableName: string;
  /** Stable Hardhat Ignition future ID for this facet. */
  futureId: string;
};

/** Everything the renderers need to produce a managed deploy script. */
export type ManagedScriptModel = {
  planHash: Hex;
  framework: "foundry" | "hardhat";
  toolbox: ScriptToolbox | null;
  /** Absolute path where the script is written. */
  outputPath: string;
  /** Absolute path of the transient Hardhat Ignition runtime, or null for Foundry. */
  runnerPath: string | null;
  /** Stable Ignition journal ID for this Compose deployment attempt, or null for Foundry. */
  ignitionDeploymentId: string | null;
  /** Absolute path of the framework's deploy result file, or null when it uses a broadcast. */
  resultPath: string | null;
  projectRoot: string;
  diamond: {
    contractName: string;
    importSpec: string;
  };
  facets: ScriptFacetEntry[];
  chainKey: string;
  chainId: number;
  instance: string;
  account: {
    alias: string;
    address: `0x${string}`;
    foundryAccount?: string;
  } | null;
};
