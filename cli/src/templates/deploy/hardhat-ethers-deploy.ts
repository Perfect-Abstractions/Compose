import { network } from "hardhat";

const { ethers, networkName } = await network.create();

async function deploy() {
  console.log(`Deploying Diamond to ${networkName}...`);

  const facets: string[] = [];

  // Base facet generation.
{{BASE_LINES}}

  // Library facet generation.
{{LIBRARY_LINES}}

  // Define diamond proxy.
  const diamond = await ethers.deployContract("Diamond", [facets]);
  await diamond.waitForDeployment();

  console.log("Diamond:", await diamond.getAddress());
}

deploy().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
