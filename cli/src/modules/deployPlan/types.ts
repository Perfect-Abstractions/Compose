import type { Hex } from "viem";
import type { ResolvedChainConfig } from "../../utils/chainConfig";
import type { DiamondDeployment } from "../lockFile/types";

/** How `compose deploy` treats the current deployment record, if any. */
export type DeployMode =
  /** No deployment record exists for the target; deploy fresh. */
  | "fresh"
  /** A record exists and its facet set matches compose.json. */
  | "in-sync"
  /** A record exists but its facet set differs from compose.json. */
  | "diff"
  /** A record exists and `--redeploy` replaces it with a fresh deploy. */
  | "redeploy";

/** One facet in the desired composition, in compose.json registration order. */
export type PlannedFacet = {
  /** compose.json facet key. */
  name: string;
  /** Solidity contract to deploy for this facet. */
  contractName: string;
  /** Absolute path of the resolved facet source file. */
  sourcePath: string;
  /** Import path usable from the managed deploy script. */
  importSpec: string;
};

/** The resolved deployment plan for one diamond on one chain instance. */
export type DeployPlan = {
  mode: DeployMode;
  framework: "foundry" | "hardhat";
  projectRoot: string;
  composeJsonPath: string;
  diamondName: string;
  diamond: {
    contractName: string;
    sourcePath: string;
    importSpec: string;
  };
  instance: string;
  chain: ResolvedChainConfig;
  /** Desired composition in compose.json registration order. */
  facets: PlannedFacet[];
  /** The existing lock record for the target; null for a fresh deployment. */
  existing: DiamondDeployment | null;
  /** Composition drift against the existing record; set when mode is "diff". */
  diff: { added: string[]; removed: string[] } | null;
  /** True when the desired composition registers DiamondUpgradeFacet. */
  upgradeable: boolean;
  /** keccak256 over the canonical plan JSON used to bind generated scripts. */
  planHash: Hex;
};
