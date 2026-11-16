import { network } from "hardhat";

const rpcUrl = process.env.COMPOSE_DEPLOY_RPC_URL;
if (!rpcUrl) throw new Error("Compose RPC URL was not provided");
const connection = await network.create({ network: {{CHAIN_KEY}}, override: { url: rpcUrl } });
if (connection.networkConfig.type !== "http") throw new Error("Selected Hardhat network must be HTTP");
const actualChainId = Number(BigInt(String(await connection.provider.request({ method: "eth_chainId", params: [] }))));
if (actualChainId !== {{CHAIN_ID}}) throw new Error("Hardhat RPC chain ID does not match Compose");
{{ACCOUNT_READ}}
console.log("COMPOSE_ACCOUNT_ADDRESSES:" + JSON.stringify(addresses));
await connection.close();
