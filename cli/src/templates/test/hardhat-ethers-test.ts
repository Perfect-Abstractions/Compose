import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.create();

describe("Diamond", function () {
  let diamondAddress: string;

  before(async function () {
    const facets: string[] = [];

    // Base facet generation.
{{BASE_LINES}}

    // Library facet generation.
{{LIBRARY_LINES}}

    const diamond = await ethers.deployContract("Diamond", [facets]);
    await diamond.waitForDeployment();
    diamondAddress = await diamond.getAddress();
  });

  it("inspect: facetAddresses returns correct count", async function () {
    const inspect = await ethers.getContractAt("DiamondInspectFacet", diamondAddress);
    const addresses = await inspect.facetAddresses();
    expect(addresses.length).to.equal({{FACET_COUNT}});
  });
});
