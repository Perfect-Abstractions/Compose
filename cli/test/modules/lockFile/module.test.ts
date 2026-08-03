import { describe, expect, it } from "vitest";
import { HashingAdapter } from "../../../src/adapters/hashingAdapter";
import { LockFileModule } from "../../../src/modules/lockFile/module";
import { ComposeLock, DiamondDeployment } from "../../../src/modules/lockFile/types";

describe("LockFileModule.isLockStale", () => {
  const createTestLock = (facetHash: string): ComposeLock => ({
    compose: "0.0.3",
    deployments: {
      MyDiamond: {
        sepolia: {
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
});

describe("LockFileModule.getDeployment", () => {
  const testLock: ComposeLock = {
    compose: "0.0.3",
    deployments: {
      MyDiamond: {
        sepolia: {
          diamond: "0x1234567890abcdef1234567890abcdef12345678",
          facets: {},
          facetHash: "0x...",
          lastSync: "2026-08-03T12:00:00Z",
          txHash: "0x...",
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
    const updated = LockFileModule.setDeployment(emptyLock, "MyDiamond", "sepolia", deployment);
    expect(updated.deployments.MyDiamond?.sepolia).toEqual(deployment);
  });

  it("does not mutate original lock", () => {
    const originalDeployments = emptyLock.deployments;
    LockFileModule.setDeployment(emptyLock, "MyDiamond", "sepolia", deployment);
    expect(emptyLock.deployments).toBe(originalDeployments);
    expect(emptyLock.deployments.MyDiamond).toBeUndefined();
  });

  it("updates existing deployment", () => {
    const lockWithDeployment = LockFileModule.setDeployment(emptyLock, "MyDiamond", "sepolia", deployment);
    const newDeployment = { ...deployment, diamond: "0x9999999999999999999999999999999999999999" };

    const updated = LockFileModule.setDeployment(lockWithDeployment, "MyDiamond", "sepolia", newDeployment);
    expect(updated.deployments.MyDiamond?.sepolia.diamond).toBe("0x9999999999999999999999999999999999999999");
  });

  it("adds deployment to new chain", () => {
    const lockWithSepolia = LockFileModule.setDeployment(emptyLock, "MyDiamond", "sepolia", deployment);
    const baseDeployment = { ...deployment, diamond: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };

    const updated = LockFileModule.setDeployment(lockWithSepolia, "MyDiamond", "base", baseDeployment);
    expect(updated.deployments.MyDiamond?.sepolia).toEqual(deployment);
    expect(updated.deployments.MyDiamond?.base.diamond).toBe("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
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
