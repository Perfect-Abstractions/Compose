import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("Counter", function () {
  it("Increment the counter", async function () {
    const counterFacet = await ethers.deployContract("CounterFacet");
    const [owner] = await ethers.getSigners();

    const diamond = await ethers.deployContract("Diamond", [
      [
        await counterFacet.getAddress()
      ],
      owner.address,
    ]);

    const counter = await ethers.getContractAt("CounterFacet", await diamond.getAddress());

    await counter.increment();
    expect(await counter.getCounter()).to.equal(1n);
  });
});

