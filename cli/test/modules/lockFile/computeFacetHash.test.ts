import { describe, expect, it } from "vitest";
import { HashingAdapter } from "../../../src/adapters/hashingAdapter";
import { LockFileModule } from "../../../src/modules/lockFile/module";

describe("LockFileModule.computeFacetHash", () => {
  it("computes consistent hash for same addresses", () => {
    const addresses = [
      "0x1234567890abcdef1234567890abcdef12345678",
      "0xabcdef1234567890abcdef1234567890abcdef12",
    ];

    const hash1 = LockFileModule.computeFacetHash(addresses, HashingAdapter);
    const hash2 = LockFileModule.computeFacetHash(addresses, HashingAdapter);

    expect(hash1).toBe(hash2);
  });

  it("normalizes to lowercase before hashing", () => {
    const addresses = [
      "0xABCDEF1234567890ABCDEF1234567890ABCDEF12",
      "0x1234567890abcdef1234567890abcdef12345678",
    ];

    const hash = LockFileModule.computeFacetHash(addresses, HashingAdapter);
    expect(hash).toMatch(/^0x[a-f0-9]{64}$/);
  });

  it("sorts addresses lexicographically", () => {
    const addresses1 = [
      "0x9876543210fedcba9876543210fedcba98765432",
      "0x1234567890abcdef1234567890abcdef12345678",
    ];
    const addresses2 = [
      "0x1234567890abcdef1234567890abcdef12345678",
      "0x9876543210fedcba9876543210fedcba98765432",
    ];

    const hash1 = LockFileModule.computeFacetHash(addresses1, HashingAdapter);
    const hash2 = LockFileModule.computeFacetHash(addresses2, HashingAdapter);

    // Same addresses in different order should produce same hash
    expect(hash1).toBe(hash2);
  });

  it("produces different hashes for different addresses", () => {
    const addresses1 = [
      "0x1234567890abcdef1234567890abcdef12345678",
    ];
    const addresses2 = [
      "0xabcdef1234567890abcdef1234567890abcdef12",
    ];

    const hash1 = LockFileModule.computeFacetHash(addresses1, HashingAdapter);
    const hash2 = LockFileModule.computeFacetHash(addresses2, HashingAdapter);

    expect(hash1).not.toBe(hash2);
  });

  it("handles single address", () => {
    const addresses = [
      "0x1234567890abcdef1234567890abcdef12345678",
    ];

    const hash = LockFileModule.computeFacetHash(addresses, HashingAdapter);
    expect(hash).toMatch(/^0x[a-f0-9]{64}$/);
  });
});
