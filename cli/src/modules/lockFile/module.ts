import fs from "node:fs/promises";
import path from "node:path";
import { type Hex } from "viem";
import { ComposeContext } from "../../context/types";
import { IHashingAdapter } from "../../adapters/interface/IHashingAdapter";
import { atomicWriteFile, findFileAncestor } from "../../utils/files";
import { ComposeLock, DiamondDeployment } from "./types";
import { validateLockFile } from "./validators";
import { LOCK_FILE_NAME } from "../../utils/metadata";

/**
 * Lock file module for reading, writing, and staleness detection.
 *
 * Provides functions to manage compose.lock, which records deployment state
 * for diamonds across chains. The lock file is machine-written and should
 * not be edited manually.
 */
export const LockFileModule = {
  /**
   * Reads and validates compose.lock from the project root.
   *
   * Searches for compose.lock by walking up the directory tree from the
   * project root. Returns null result if file doesn't exist (not an error).
   * Throws if file exists but is invalid.
   *
   * @param ctx - The compose context with project root parameter.
   * @returns The updated context with lock file state.
   */
  async readLockFile(ctx: ComposeContext): Promise<ComposeContext> {
    const startDir = String(ctx.param.projectRoot ?? process.cwd());
    const lockFilePath = await findFileAncestor(startDir, LOCK_FILE_NAME);

    if (!lockFilePath) {
      ctx.state.lockFile = {
        success: true,
        result: null,
        error: null,
      };
      return ctx;
    }

    try {
      const content = await fs.readFile(lockFilePath, "utf8");
      const data = JSON.parse(content);
      validateLockFile(data);

      ctx.state.lockFile = {
        success: true,
        result: {
          path: lockFilePath,
          lock: data as ComposeLock,
        },
        error: null,
      };
    } catch (error) {
      ctx.state.lockFile = {
        success: false,
        result: null,
        error: {
          code: "LOCK_FILE_INVALID",
          message: error instanceof Error ? error.message : "Failed to read lock file",
          nativeError: error,
        },
      };
    }

    return ctx;
  },

  /**
   * Atomically writes compose.lock to the project root.
   *
   * Writes to a temp file first, then renames to prevent corruption on crash.
   * Creates intermediate directories if needed.
   *
   * @param ctx - The compose context with project root parameter.
   * @param lock - The lock file content to write.
   * @returns The updated context with write state.
   */
  async writeLockFile(ctx: ComposeContext, lock: ComposeLock): Promise<ComposeContext> {
    const projectRoot = String(ctx.param.projectRoot ?? process.cwd());
    const lockFilePath = path.join(projectRoot, LOCK_FILE_NAME);

    try {
      const content = JSON.stringify(lock, null, 2);
      await atomicWriteFile(lockFilePath, content);

      ctx.state.lockFileWrite = {
        success: true,
        result: { path: lockFilePath },
        error: null,
      };
    } catch (error) {
      ctx.state.lockFileWrite = {
        success: false,
        result: null,
        error: {
          code: "LOCK_FILE_WRITE_FAILED",
          message: error instanceof Error ? error.message : "Failed to write lock file",
          nativeError: error,
        },
      };
    }

    return ctx;
  },

  /**
   * Computes facetHash from an array of facet addresses.
   *
   * Algorithm:
   * 1. Convert all addresses to lowercase
   * 2. Sort lexicographically
   * 3. Concatenate (with 0x prefix)
   * 4. Hash with keccak256
   *
   * @param addresses - Array of facet addresses.
   * @param hashing - Hashing adapter for keccak256 computation.
   * @returns The facet hash as a hex string.
   */
  computeFacetHash(addresses: Hex[], hashing: IHashingAdapter): Hex {
    const normalized = addresses
      .map((addr) => addr.toLowerCase())
      .sort();

    const concatenated = normalized.join("");
    return hashing.keccak256(concatenated);
  },

  /**
   * Checks if the lock file is stale by comparing computed vs stored facetHash.
   *
   * A lock file is considered stale when the on-chain facet addresses differ
   * from what's recorded in the lock file.
   *
   * @param lock - The current lock file content.
   * @param diamondName - The diamond to check.
   * @param chain - The chain to check.
   * @param facetAddresses - Current on-chain facet addresses.
   * @param hashing - Hashing adapter for keccak256 computation.
   * @returns True if the lock file is stale.
   */
  isLockStale(
    lock: ComposeLock,
    diamondName: string,
    chain: string,
    facetAddresses: Hex[],
    hashing: IHashingAdapter,
  ): boolean {
    const deployment = lock.deployments[diamondName]?.[chain];
    if (!deployment) {
      return true;
    }

    const computedHash = LockFileModule.computeFacetHash(facetAddresses, hashing);
    return computedHash !== deployment.facetHash;
  },

  /**
   * Gets a deployment from the lock file.
   *
   * @param lock - The lock file content.
   * @param diamondName - The diamond name.
   * @param chain - The chain name.
   * @returns The deployment or undefined if not found.
   */
  getDeployment(
    lock: ComposeLock,
    diamondName: string,
    chain: string,
  ): DiamondDeployment | undefined {
    return lock.deployments[diamondName]?.[chain];
  },

  /**
   * Updates or adds a deployment in the lock file.
   *
   * Returns a new lock file object with the deployment updated.
   * Does not mutate the original lock file.
   *
   * @param lock - The lock file content to update.
   * @param diamondName - The diamond name.
   * @param chain - The chain name.
   * @param deployment - The deployment details.
   * @returns The updated lock file content.
   */
  setDeployment(
    lock: ComposeLock,
    diamondName: string,
    chain: string,
    deployment: DiamondDeployment,
  ): ComposeLock {
    return {
      ...lock,
      deployments: {
        ...lock.deployments,
        [diamondName]: {
          ...lock.deployments[diamondName],
          [chain]: deployment,
        },
      },
    };
  },

  /**
   * Creates an empty lock file structure.
   *
   * @param composeVersion - The compose schema version.
   * @returns An empty lock file.
   */
  createEmptyLock(composeVersion: string): ComposeLock {
    return {
      compose: composeVersion,
      deployments: {},
    };
  },
};
