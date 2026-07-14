import { network } from "hardhat";

const { viem, networkName } = await network.create();

async function deploy() {
  console.log(`Deploying Diamond to ${networkName}...`);

  const facets: `0x${string}`[] = [];

  // Base facet generation.
{{BASE_LINES}}

  // Library facet generation.
{{LIBRARY_LINES}}

  // Define diamond proxy.
  const diamond = await viem.deployContract("Diamond", [facets]);

  console.log("Diamond:", diamond.address);
}

deploy().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
