import fs from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import { network } from "hardhat";
import ComposeDeploy from "{{MODULE_IMPORT}}";

const composeMode = process.env.COMPOSE_DEPLOY_MODE;
const simulation = composeMode === "simulate";
const rpcUrl = process.env.COMPOSE_DEPLOY_RPC_URL;
const expectedChainId = {{CHAIN_ID}};
const ignitionDeploymentId: string = {{IGNITION_DEPLOYMENT_ID}};
const expectedAccountAddress: string | null = {{ACCOUNT_ADDRESS}};
const resultPath = {{RESULT_PATH}};

if (!rpcUrl) {
  throw new Error("Compose did not provide the RPC URL. Run this with 'compose deploy'.");
}

async function addressOf(contract: {
  getAddress?: () => Promise<string>;
  address?: string;
}): Promise<string> {
  if (typeof contract.getAddress === "function") return contract.getAddress();
  if (typeof contract.address === "string") return contract.address;
  throw new Error("Hardhat Ignition returned a contract without an address.");
}

async function main() {
  const targetConnection = await network.create({
    network: {{CHAIN_KEY}},
    override: { url: rpcUrl },
  });
  if (targetConnection.networkConfig.type !== "http") {
    throw new Error(
      `Hardhat network '${targetConnection.networkName}' is not an HTTP network. Configure it as an HTTP network for Compose deployments.`,
    );
  }

  const chainIdHex = await targetConnection.provider.request({ method: "eth_chainId", params: [] });
  const actualChainId = Number(BigInt(String(chainIdHex)));
  if (!Number.isSafeInteger(actualChainId) || actualChainId !== expectedChainId) {
    throw new Error(`Compose RPC endpoint reports chain id ${actualChainId}; expected ${expectedChainId}.`);
  }

{{RESOLVE_SIGNER}}

  let deploymentConnection = targetConnection;
  let forkBlockNumber: number | null = null;
  let executionSender = deployerAddress;
  const executionDeploymentId = simulation
    ? `${ignitionDeploymentId}-simulation-${randomUUID()}`
    : ignitionDeploymentId;
  if (simulation) {
    const configuredForkBlock = Number(process.env.COMPOSE_DEPLOY_FORK_BLOCK_NUMBER);
    if (!Number.isSafeInteger(configuredForkBlock) || configuredForkBlock < 0) {
      throw new Error("Compose did not provide a valid fork block for the deployment simulation.");
    }
    forkBlockNumber = configuredForkBlock;
    deploymentConnection = await network.create({
      network: "default",
      chainType: targetConnection.networkConfig.chainType ?? "generic",
      override: {
        chainId: actualChainId,
        forking: { url: rpcUrl, blockNumber: forkBlockNumber },
      },
    });
    const forkAccounts = await deploymentConnection.provider.request({ method: "eth_accounts", params: [] });
    if (!Array.isArray(forkAccounts) || typeof forkAccounts[0] !== "string") {
      throw new Error("Hardhat Ignition simulation has no local account available on the fork.");
    }
    executionSender = forkAccounts.find((address) =>
      typeof address === "string" && address.toLowerCase() === deployerAddress.toLowerCase(),
    ) ?? forkAccounts[0];
    if (executionSender.toLowerCase() !== deployerAddress.toLowerCase()) {
      console.log(`Using local fork account ${executionSender} for simulation; the configured deployment account remains ${deployerAddress}.`);
    }
    console.log(`Simulating Ignition deployment on fork block ${forkBlockNumber}...`);
  } else {
    console.log(`Broadcasting Ignition deployment to ${targetConnection.networkName}...`);
  }

  try {
    console.log("Deployer:", simulation ? executionSender : deployerAddress);
    const outputs = await deploymentConnection.ignition.deploy(ComposeDeploy, {
      deploymentId: executionDeploymentId,
      defaultSender: executionSender,
    });
    const diamondAddress = await addressOf(outputs.diamond);
    const facets = {
{{FACET_ADDRESS_ENTRIES}}
    };

    if (simulation) {
      console.log("Simulated Diamond:", diamondAddress);
      console.log("Simulation succeeded. No transactions were broadcast.");
      return;
    }

    await fs.mkdir(path.dirname(resultPath), { recursive: true });
    await fs.writeFile(resultPath, JSON.stringify({
      mode: "deploy",
      planHash: "{{PLAN_HASH}}",
      framework: "hardhat",
      chainKey: {{CHAIN_KEY}},
      chainId: actualChainId,
      instance: {{INSTANCE}},
      deployer: deployerAddress,
      diamond: diamondAddress,
      facets,
      ignitionDeploymentId,
    }, null, 2));
    console.log("Ignition deployment complete:", resultPath);
  } finally {
    if (simulation) {
      await deploymentConnection.close();
      await fs.rm(path.resolve("ignition", "deployments", executionDeploymentId), {
        recursive: true,
        force: true,
      });
    }
    await targetConnection.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
