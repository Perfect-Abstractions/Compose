import assert from "node:assert";
import { describe, test, before } from "node:test";
import { network } from "hardhat";

const { viem } = await network.create();

describe("Diamond", () => {
  let diamondAddress: `0x${string}`;

  before(async () => {
    const facets: `0x${string}`[] = [];

    // Base facet generation.
{{BASE_LINES}}

    // Library facet generation.
{{LIBRARY_LINES}}

    const diamond = await viem.deployContract("Diamond", [facets]);
    diamondAddress = diamond.address;
  });

  test("inspect: facetAddresses returns correct count", async () => {
    const inspect = await viem.getContractAt("DiamondInspectFacet", diamondAddress);
    const addresses = await inspect.read.facetAddresses();
    assert.strictEqual(addresses.length, {{FACET_COUNT}});
  });
});
