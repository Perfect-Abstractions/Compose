import { isAddress } from "viem";

/**
 * Validates a parsed lock file object structure.
 * Throws descriptive errors for invalid fields.
 *
 * @param data - The parsed JSON object to validate.
 * @throws {Error} If the lock file structure is invalid.
 */
export function validateLockFile(data: unknown): void {
  if (!data || typeof data !== "object") {
    throw new Error("Lock file must be a JSON object");
  }

  const lock = data as Record<string, unknown>;

  // Validate compose version
  if (typeof lock.compose !== "string") {
    throw new Error("Lock file missing 'compose' version string");
  }

  // Validate deployments
  if (!lock.deployments || typeof lock.deployments !== "object") {
    throw new Error("Lock file missing 'deployments' object");
  }

  const deployments = lock.deployments as Record<string, unknown>;
  for (const [diamondName, diamondData] of Object.entries(deployments)) {
    validateDiamondDeployments(diamondName, diamondData);
  }
}

/**
 * Validates the deployments structure for a specific diamond.
 *
 * @param diamondName - The diamond name being validated.
 * @param data - The diamond deployments data.
 * @throws {Error} If the diamond deployments structure is invalid.
 */
function validateDiamondDeployments(diamondName: string, data: unknown): void {
  if (!data || typeof data !== "object") {
    throw new Error(`Diamond '${diamondName}' must be an object`);
  }

  const chains = data as Record<string, unknown>;
  for (const [chainName, chainData] of Object.entries(chains)) {
    validateChainDeployment(diamondName, chainName, chainData);
  }
}

/**
 * Validates a chain deployment entry.
 *
 * @param diamondName - The diamond name being validated.
 * @param chainName - The chain name being validated.
 * @param data - The chain deployment data.
 * @throws {Error} If the chain deployment structure is invalid.
 */
function validateChainDeployment(diamondName: string, chainName: string, data: unknown): void {
  if (!data || typeof data !== "object") {
    throw new Error(`Deployment for '${diamondName}' on '${chainName}' must be an object`);
  }

  const deployment = data as Record<string, unknown>;
  const prefix = `'${diamondName}' on '${chainName}'`;

  // Validate diamond address
  if (typeof deployment.diamond !== "string" || !isAddress(deployment.diamond, { strict: false })) {
    throw new Error(`${prefix}: invalid or missing 'diamond' address`);
  }

  // Validate facets
  if (!deployment.facets || typeof deployment.facets !== "object") {
    throw new Error(`${prefix}: missing 'facets' object`);
  }

  const facets = deployment.facets as Record<string, unknown>;
  for (const [facetName, facetAddress] of Object.entries(facets)) {
    if (typeof facetAddress !== "string" || !isAddress(facetAddress, { strict: false })) {
      throw new Error(`${prefix}: invalid address for facet '${facetName}'`);
    }
  }

  // Validate facetHash
  if (typeof deployment.facetHash !== "string" || !deployment.facetHash.startsWith("0x")) {
    throw new Error(`${prefix}: invalid or missing 'facetHash'`);
  }

  // Validate lastSync
  if (typeof deployment.lastSync !== "string" || isNaN(Date.parse(deployment.lastSync))) {
    throw new Error(`${prefix}: invalid or missing 'lastSync' timestamp`);
  }

  // Validate txHash
  if (typeof deployment.txHash !== "string" || !deployment.txHash.startsWith("0x")) {
    throw new Error(`${prefix}: invalid or missing 'txHash'`);
  }
}
