import { describe, expect, it } from "vitest";
import { escapeRegExp } from "../../src/utils/regex";

/**
 * Tests escapeRegExp with Solidity-like names containing regex metacharacters.
 *
 * The escaped result must remain safe when embedded in a RegExp pattern.
 */
describe("escapeRegExp", () => {
  it("matches regex metacharacters as literal text", () => {
    const value = "Facet[0].getValue(address,uint256) + $slot? \\ path";
    const pattern = new RegExp(`^${escapeRegExp(value)}$`);

    expect(pattern.test(value)).toBe(true);
    expect(pattern.test("Facet0.getValueaddress,uint256 + slot path")).toBe(false);
  });

  it("leaves plain text unchanged", () => {
    expect(escapeRegExp("ERC20TransferFacet")).toBe("ERC20TransferFacet");
  });
});
