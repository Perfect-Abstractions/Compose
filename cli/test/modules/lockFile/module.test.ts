import { describe, expect, it } from "vitest";
import { HashingAdapter } from "../../../src/adapters/IHashingAdapter/adapter";
import { LockFileModule } from "../../../src/modules/lockFile/module";
import { ComposeLock, DiamondDeployment } from "../../../src/modules/lockFile/types";

describe("LockFileModule.isLockStale", () => {
  const createTestLock = (facetHash: string): ComposeLock => ({
    compose: "0.0.3",
    deployments: {
      MyDiamond: {
        sepolia: {
          default: {
            diamond: "0x1234567890abcdef1234567890abcdef12345678",
            facets: {
              FacetA: "0xabcdef1234567890abcdef1234567890abcdef12",
            },
            facetHash,
            lastSync: "2026-08-03T12:00:00Z",
            txHash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12",
          },
        },
      },
    },
  });

  it("returns true when diamond not found in lock", () => {
    const lock = createTestLock("0x...");
    const addresses = ["0xabcdef1234567890abcdef1234567890abcdef12"];

    const stale = LockFileModule.isLockStale(lock, "UnknownDiamond", "sepolia", addresses, HashingAdapter);
    expect(stale).toBe(true);
  });

  it("returns true when chain not found in lock", () => {
    const lock = createTestLock("0x...");
    const addresses = ["0xabcdef1234567890abcdef1234567890abcdef12"];

    const stale = LockFileModule.isLockStale(lock, "MyDiamond", "mainnet", addresses, HashingAdapter);
    expect(stale).toBe(true);
  });

  it("returns true when facet addresses differ", () => {
    const lock = createTestLock("0x0000000000000000000000000000000000000000000000000000000000000000");
    const addresses = ["0xabcdef1234567890abcdef1234567890abcdef12"];

    const stale = LockFileModule.isLockStale(lock, "MyDiamond", "sepolia", addresses, HashingAdapter);
    expect(stale).toBe(true);
  });

  it("returns false when facet addresses match", () => {
    const addresses = ["0xabcdef1234567890abcdef1234567890abcdef12"];
    const facetHash = LockFileModule.computeFacetHash(addresses, HashingAdapter);
    const lock = createTestLock(facetHash);

    const stale = LockFileModule.isLockStale(lock, "MyDiamond", "sepolia", addresses, HashingAdapter);
    expect(stale).toBe(false);
  });

  it("returns true when the instance is not recorded", () => {
    const addresses = ["0xabcdef1234567890abcdef1234567890abcdef12"];
    const facetHash = LockFileModule.computeFacetHash(addresses, HashingAdapter);
    const lock = createTestLock(facetHash);

    const stale = LockFileModule.isLockStale(
      lock,
      "MyDiamond",
      "sepolia",
      addresses,
      HashingAdapter,
      "staging",
    );
    expect(stale).toBe(true);
  });
});

describe("LockFileModule.getDeployment", () => {
  const testLock: ComposeLock = {
    compose: "0.0.3",
    deployments: {
      MyDiamond: {
        sepolia: {
          default: {
            diamond: "0x1234567890abcdef1234567890abcdef12345678",
            facets: {},
            facetHash: "0x...",
            lastSync: "2026-08-03T12:00:00Z",
            txHash: "0x...",
          },
        },
      },
    },
  };

  it("returns deployment when found", () => {
    const deployment = LockFileModule.getDeployment(testLock, "MyDiamond", "sepolia");
    expect(deployment).toBeDefined();
    expect(deployment?.diamond).toBe("0x1234567890abcdef1234567890abcdef12345678");
  });

  it("returns undefined when diamond not found", () => {
    const deployment = LockFileModule.getDeployment(testLock, "UnknownDiamond", "sepolia");
    expect(deployment).toBeUndefined();
  });

  it("returns undefined when chain not found", () => {
    const deployment = LockFileModule.getDeployment(testLock, "MyDiamond", "mainnet");
    expect(deployment).toBeUndefined();
  });

  it("reads a named instance without falling back to the default instance", () => {
    const staging: DiamondDeployment = {
      diamond: "0x9999999999999999999999999999999999999999",
      facets: {},
      facetHash: "0x...",
      lastSync: "2026-08-03T12:00:00Z",
      txHash: "0x...",
    };
    const lock = LockFileModule.setDeployment(testLock, "MyDiamond", "sepolia", "staging", staging);

    expect(LockFileModule.getDeployment(lock, "MyDiamond", "sepolia", "staging")).toEqual(staging);
    expect(LockFileModule.getDeployment(lock, "MyDiamond", "sepolia")?.diamond).toBe(
      "0x1234567890abcdef1234567890abcdef12345678",
    );
  });
});

describe("LockFileModule.setDeployment", () => {
  const emptyLock: ComposeLock = {
    compose: "0.0.3",
    deployments: {},
  };

  const deployment: DiamondDeployment = {
    diamond: "0x1234567890abcdef1234567890abcdef12345678",
    facets: {},
    facetHash: "0x...",
    lastSync: "2026-08-03T12:00:00Z",
    txHash: "0x...",
  };

  it("adds new deployment to empty lock", () => {
    const updated = LockFileModule.setDeployment(emptyLock, "MyDiamond", "sepolia", "default", deployment);
    expect(updated.deployments.MyDiamond?.sepolia.default).toEqual(deployment);
  });

  it("does not mutate original lock", () => {
    const originalDeployments = emptyLock.deployments;
    LockFileModule.setDeployment(emptyLock, "MyDiamond", "sepolia", "default", deployment);
    expect(emptyLock.deployments).toBe(originalDeployments);
    expect(emptyLock.deployments.MyDiamond).toBeUndefined();
  });

  it("updates existing deployment", () => {
    const lockWithDeployment = LockFileModule.setDeployment(
      emptyLock,
      "MyDiamond",
      "sepolia",
      "default",
      deployment,
    );
    const newDeployment = { ...deployment, diamond: "0x9999999999999999999999999999999999999999" };

    const updated = LockFileModule.setDeployment(
      lockWithDeployment,
      "MyDiamond",
      "sepolia",
      "default",
      newDeployment,
    );
    expect(updated.deployments.MyDiamond?.sepolia.default.diamond)
      .toBe("0x9999999999999999999999999999999999999999");
  });

  it("adds deployment to new chain", () => {
    const lockWithSepolia = LockFileModule.setDeployment(
      emptyLock,
      "MyDiamond",
      "sepolia",
      "default",
      deployment,
    );
    const baseDeployment = { ...deployment, diamond: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };

    const updated = LockFileModule.setDeployment(
      lockWithSepolia,
      "MyDiamond",
      "base",
      "default",
      baseDeployment,
    );
    expect(updated.deployments.MyDiamond?.sepolia.default).toEqual(deployment);
    expect(updated.deployments.MyDiamond?.base.default.diamond)
      .toBe("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
  });

  it("keeps instances on the same chain independent", () => {
    const lock = LockFileModule.setDeployment(
      emptyLock,
      "MyDiamond",
      "sepolia",
      "default",
      deployment,
    );
    const staging = { ...deployment, diamond: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" };

    const updated = LockFileModule.setDeployment(lock, "MyDiamond", "sepolia", "staging", staging);
    expect(updated.deployments.MyDiamond?.sepolia.default).toEqual(deployment);
    expect(updated.deployments.MyDiamond?.sepolia.staging).toEqual(staging);
  });

  it("rejects an empty instance name", () => {
    expect(() => LockFileModule.setDeployment(emptyLock, "MyDiamond", "sepolia", "", deployment))
      .toThrow("Deployment instance must be a non-empty string.");
  });
});

describe("LockFileModule.createEmptyLock", () => {
  it("creates lock with specified version", () => {
    const lock = LockFileModule.createEmptyLock("0.0.3");
    expect(lock.compose).toBe("0.0.3");
    expect(lock.deployments).toEqual({});
  });

  it("creates lock with empty deployments", () => {
    const lock = LockFileModule.createEmptyLock("1.0.0");
    expect(Object.keys(lock.deployments)).toHaveLength(0);
  });
});
