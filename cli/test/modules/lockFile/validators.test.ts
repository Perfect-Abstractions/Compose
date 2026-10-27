import { describe, expect, it } from "vitest";
import { validateLockFile } from "../../../src/modules/lockFile/validators";

const deployment = {
  diamond: "0x1234567890abcdef1234567890abcdef12345678",
  facets: {
    FacetA: "0xabcdef1234567890abcdef1234567890abcdef12",
  },
  facetHash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12",
  lastSync: "2026-08-03T12:00:00Z",
  txHash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12",
};

function lockWith(chainDeployments: unknown) {
  return {
    compose: "0.0.3",
    deployments: {
      MyDiamond: {
        sepolia: chainDeployments,
      },
    },
  };
}

function lockWithDeployment(overrides: Record<string, unknown>, instance = "default") {
  return lockWith({ [instance]: { ...deployment, ...overrides } });
}

describe("validateLockFile", () => {
  const validLock = lockWith({ default: deployment });

  it("accepts valid lock file structure", () => {
    expect(() => validateLockFile(validLock)).not.toThrow();
  });

  it("accepts optional Hardhat Ignition deployment metadata", () => {
    expect(() => validateLockFile(lockWithDeployment({
      ignitionDeploymentId: "compose-my-diamond-local-default-abcdef12",
    }))).not.toThrow();
  });

  it("rejects an empty Hardhat Ignition deployment ID", () => {
    expect(() => validateLockFile(lockWithDeployment({ ignitionDeploymentId: "" })))
      .toThrow("invalid 'ignitionDeploymentId'");
  });

  it("accepts multiple instances on one chain", () => {
    expect(() => validateLockFile(lockWith({
      default: deployment,
      staging: { ...deployment, diamond: "0x9999999999999999999999999999999999999999" },
    }))).not.toThrow();
  });

  it("rejects null input", () => {
    expect(() => validateLockFile(null)).toThrow("Lock file must be a JSON object");
  });

  it("rejects non-object input", () => {
    expect(() => validateLockFile("string")).toThrow("Lock file must be a JSON object");
  });

  it("rejects missing compose version", () => {
    const invalid = { deployments: {} };
    expect(() => validateLockFile(invalid)).toThrow("missing 'compose' version string");
  });

  it("rejects invalid compose version", () => {
    const invalid = { compose: 123, deployments: {} };
    expect(() => validateLockFile(invalid)).toThrow("missing 'compose' version string");
  });

  it("rejects missing deployments", () => {
    const invalid = { compose: "0.0.3" };
    expect(() => validateLockFile(invalid)).toThrow("missing 'deployments' object");
  });

  it("rejects non-object deployments", () => {
    const invalid = { compose: "0.0.3", deployments: "string" };
    expect(() => validateLockFile(invalid)).toThrow("missing 'deployments' object");
  });

  it("rejects non-object chain deployments", () => {
    expect(() => validateLockFile(lockWith("string")))
      .toThrow("Deployments for 'MyDiamond' on 'sepolia' must be an object");
  });

  it("rejects non-object instance deployments", () => {
    expect(() => validateLockFile(lockWith({ default: "string" })))
      .toThrow("Deployment for 'MyDiamond' on 'sepolia' instance 'default' must be an object");
  });

  it("explains the legacy two-level lock format", () => {
    expect(() => validateLockFile(lockWith(deployment))).toThrow("legacy lock format");
  });

  it("rejects invalid diamond address", () => {
    const invalid = lockWithDeployment({ diamond: "not-an-address" });
    expect(() => validateLockFile(invalid)).toThrow("invalid or missing 'diamond' address");
  });

  it("rejects missing facets", () => {
    const invalid = lockWithDeployment({ facets: undefined });
    expect(() => validateLockFile(invalid)).toThrow("missing 'facets' object");
  });

  it("rejects invalid facet address", () => {
    const invalid = lockWithDeployment({ facets: { FacetA: "not-an-address" } });
    expect(() => validateLockFile(invalid)).toThrow("invalid address for facet 'FacetA'");
  });

  it("rejects missing facetHash", () => {
    const invalid = lockWithDeployment({ facetHash: undefined });
    expect(() => validateLockFile(invalid)).toThrow("invalid or missing 'facetHash'");
  });

  it("rejects invalid lastSync", () => {
    const invalid = lockWithDeployment({ lastSync: "not-a-date" });
    expect(() => validateLockFile(invalid)).toThrow("invalid or missing 'lastSync' timestamp");
  });

  it("rejects missing txHash", () => {
    const invalid = lockWithDeployment({ txHash: undefined });
    expect(() => validateLockFile(invalid)).toThrow("invalid or missing 'txHash'");
  });

  it("names the offending instance in field errors", () => {
    const invalid = lockWithDeployment({ diamond: "not-an-address" }, "staging");
    expect(() => validateLockFile(invalid)).toThrow(
      "'MyDiamond' on 'sepolia' instance 'staging': invalid or missing 'diamond' address",
    );
  });
});
