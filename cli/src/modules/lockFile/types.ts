import { type Hex } from "viem";

/** Instance used when a command does not select one. */
export const DEFAULT_INSTANCE = "default";

/** Top-level compose.lock structure */
export type ComposeLock = {
  /** Compose schema version (e.g., "0.0.3") */
  compose: string;
  /** Deployments organized by diamond name, chain, and instance */
  deployments: Deployments;
};

/** Map of diamond names to their chain deployments */
export type Deployments = Record<string, ChainDeployments>;

/** Map of chain names to instance deployments */
export type ChainDeployments = Record<string, InstanceDeployments>;

/** Map of instance names to deployment details */
export type InstanceDeployments = Record<string, DiamondDeployment>;

/** Deployment details for a specific diamond on a specific chain instance */
export type DiamondDeployment = {
  /** Diamond proxy contract address */
  diamond: Hex;
  /** Map of facet names to their deployed addresses */
  facets: Record<string, Hex>;
  /** keccak256 hash of sorted facet addresses for staleness detection */
  facetHash: Hex;
  /** ISO 8601 timestamp of last sync with on-chain state */
  lastSync: string;
  /** Transaction hash of the deployment/upgrade */
  txHash: Hex;
  /** Public address that broadcast the deployment, when reported by the framework. */
  deployer?: Hex;
  /** Hardhat Ignition journal identity, when the deployment used Ignition. */
  ignitionDeploymentId?: string;
};

/** State stored in ctx.state.lockFile after reading */
export type LockFileState = {
  path: string;
  lock: ComposeLock;
};

/** State stored in ctx.state.lockFileWrite after writing */
export type LockFileWriteState = {
  path: string;
};
