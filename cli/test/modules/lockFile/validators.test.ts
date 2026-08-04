import { describe, expect, it } from "vitest";
import { validateLockFile } from "../../../src/modules/lockFile/validators";

describe("validateLockFile", () => {
  const validLock = {
    compose: "0.0.3",
    deployments: {
      MyDiamond: {
        sepolia: {
          diamond: "0x1234567890abcdef1234567890abcdef12345678",
          facets: {
            FacetA: "0xabcdef1234567890abcdef1234567890abcdef12",
          },
          facetHash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12",
          lastSync: "2026-08-03T12:00:00Z",
          txHash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12",
        },
      },
    },
  };

  it("accepts valid lock file structure", () => {
    expect(() => validateLockFile(validLock)).not.toThrow();
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

  it("rejects non-string compose version", () => {
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

  it("rejects invalid diamond address", () => {
    const invalid = {
      compose: "0.0.3",
      deployments: {
        MyDiamond: {
          sepolia: {
            diamond: "not-an-address",
            facets: {},
            facetHash: "0x...",
            lastSync: "2026-08-03T12:00:00Z",
            txHash: "0x...",
          },
        },
      },
    };

    expect(() => validateLockFile(invalid)).toThrow("invalid or missing 'diamond' address");
  });

  it("rejects missing facets", () => {
    const invalid = {
      compose: "0.0.3",
      deployments: {
        MyDiamond: {
          sepolia: {
            diamond: "0x1234567890abcdef1234567890abcdef12345678",
            facetHash: "0x...",
            lastSync: "2026-08-03T12:00:00Z",
            txHash: "0x...",
          },
        },
      },
    };

    expect(() => validateLockFile(invalid)).toThrow("missing 'facets' object");
  });

  it("rejects invalid facet address", () => {
    const invalid = {
      compose: "0.0.3",
      deployments: {
        MyDiamond: {
          sepolia: {
            diamond: "0x1234567890abcdef1234567890abcdef12345678",
            facets: {
              FacetA: "not-an-address",
            },
            facetHash: "0x...",
            lastSync: "2026-08-03T12:00:00Z",
            txHash: "0x...",
          },
        },
      },
    };

    expect(() => validateLockFile(invalid)).toThrow("invalid address for facet 'FacetA'");
  });

  it("rejects missing facetHash", () => {
    const invalid = {
      compose: "0.0.3",
      deployments: {
        MyDiamond: {
          sepolia: {
            diamond: "0x1234567890abcdef1234567890abcdef12345678",
            facets: {},
            lastSync: "2026-08-03T12:00:00Z",
            txHash: "0x...",
          },
        },
      },
    };

    expect(() => validateLockFile(invalid)).toThrow("invalid or missing 'facetHash'");
  });

  it("rejects invalid lastSync", () => {
    const invalid = {
      compose: "0.0.3",
      deployments: {
        MyDiamond: {
          sepolia: {
            diamond: "0x1234567890abcdef1234567890abcdef12345678",
            facets: {},
            facetHash: "0x...",
            lastSync: "not-a-date",
            txHash: "0x...",
          },
        },
      },
    };

    expect(() => validateLockFile(invalid)).toThrow("invalid or missing 'lastSync' timestamp");
  });

  it("rejects missing txHash", () => {
    const invalid = {
      compose: "0.0.3",
      deployments: {
        MyDiamond: {
          sepolia: {
            diamond: "0x1234567890abcdef1234567890abcdef12345678",
            facets: {},
            facetHash: "0x...",
            lastSync: "2026-08-03T12:00:00Z",
          },
        },
      },
    };

    expect(() => validateLockFile(invalid)).toThrow("invalid or missing 'txHash'");
  });
});
