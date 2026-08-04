import { type Hex } from "viem";

/** Top-level compose.lock structure */
export type ComposeLock = {
  /** Compose schema version (e.g., "0.0.3") */
  compose: string;
  /** Deployments organized by diamond name and chain */
  deployments: Deployments;
};

/** Map of diamond names to their chain deployments */
export type Deployments = Record<string, ChainDeployments>;

/** Map of chain names to deployment details */
export type ChainDeployments = Record<string, DiamondDeployment>;

/** Deployment details for a specific diamond on a specific chain */
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
