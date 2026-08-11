import { describe, expect, it } from "vitest";
import { HashingAdapter } from "../../src/adapters/hashingAdapter";

/**
 * Tests HashingAdapter against the full Keccak-256 digest of a Solidity signature.
 *
 * Selector derivation is intentionally outside this adapter test.
 */
describe("HashingAdapter", () => {
  it("hashes Solidity function signatures with keccak256", () => {
    expect(HashingAdapter.keccak256("transfer(address,uint256)")).toBe(
      "0xa9059cbb2ab09eb219583f4a59a5d0623ade346d962bcd4e46b11da047c9049b",
    );
  });
});
