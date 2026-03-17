import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

describe("Counter", async function () {
  const { viem } = await network.connect();
  const walletClients = await viem.getWalletClients();
  const owner = walletClients[0];

  it("Increment the counter", async function () {
    const counterFacet = await viem.deployContract("CounterFacet");

    const diamond = await viem.deployContract("Diamond", [
      [counterFacet.address],
      owner.account.address,
    ]);

    const counter = await viem.getContractAt("CounterFacet", diamond.address);

    await counter.write.increment();
    assert.equal(await counter.read.getCounter(), 1n);
  });
});

