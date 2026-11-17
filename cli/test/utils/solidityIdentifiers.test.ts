import { describe, expect, it } from "vitest";
import {
  assertSafeSolidityImportSpec,
  assertSolidityContractName,
  isSolidityIdentifier,
} from "../../src/utils/solidityIdentifiers";

describe("isSolidityIdentifier", () => {
  it.each(["Diamond", "_Facet", "Facet2", "ERC721Facet", "__proto__"])(
    "accepts %s",
    (name) => {
      expect(isSolidityIdentifier(name)).toBe(true);
    },
  );

  it.each([
    "",
    "1Facet",
    "Facet-Name",
    "Facet Name",
    "Facet.sol",
    'Facet";',
    "Facet\n",
    "Facet\\Name",
    "Facet$Name",
  ])("rejects %j", (name) => {
    expect(isSolidityIdentifier(name)).toBe(false);
  });
});

describe("assertSolidityContractName", () => {
  it("throws with an escaped representation of the rejected value", () => {
    expect(() => assertSolidityContractName('Facet";\ncontract Evil {}', 'facet "Evil"'))
      .toThrow("Invalid Solidity contract name");
  });
});

describe("assertSafeSolidityImportSpec", () => {
  it.each([
    "../src/Diamond.sol",
    "./Diamond.sol",
    "@perfect-abstractions/compose/diamond/DiamondInspectFacet.sol",
    "../src/My File.sol",
  ])("accepts %s", (spec) => {
    expect(() => assertSafeSolidityImportSpec(spec, "test import")).not.toThrow();
  });

  it.each([
    "",
    '../src/Evil".sol',
    "../src/Evil\nName.sol",
    "../src/Evil\rName.sol",
    "../src/Evil\\Name.sol",
    "../src/Evil\u001b.sol",
    "../src/Evil\u2028Name.sol",
  ])("rejects %j", (spec) => {
    expect(() => assertSafeSolidityImportSpec(spec, "test import")).toThrow(
      "Invalid Solidity import path",
    );
  });
});
