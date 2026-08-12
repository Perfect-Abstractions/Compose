import {
  createPublicClient,
  defineChain,
  getAddress,
  http,
  type Address,
  type Chain,
  type Hex,
  type ReadContractParameters,
} from "viem";
import type { IRPCAdapter, RPCReadContractOptions } from "../interface/IRPCAdapter";
import { requestError, RPCAdapterError } from "./errors";
import { retryRPC } from "./retry";
import type { RPCAdapterOptions } from "./types";
import { validateOptions } from "./validation";

/**
 * Creates the minimal viem chain definition needed by a custom RPC endpoint.
 * @param chainId Expected EVM chain ID.
 * @param rpcUrl HTTP or HTTPS JSON-RPC endpoint.
 * @returns A viem chain definition bound to the endpoint.
 */
function chainFor(chainId: number, rpcUrl: string): Chain {
  return defineChain({
    id: chainId,
    name: `Compose chain ${chainId}`,
    nativeCurrency: { name: "Native", symbol: "NATIVE", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
  });
}

/**
 * Creates an isolated, chain-specific read-only RPC adapter.
 *
 * Construction performs a chain-ID probe, so a successfully created adapter
 * has already verified that its endpoint points at the requested network.
 * Requests use the adapter retry policy rather than viem transport retries.
 * @param options RPC endpoint and expected chain configuration.
 * @returns A configured read-only RPC adapter.
 * @throws {RPCAdapterError} If configuration is invalid, the endpoint is
 * unreachable, unauthorized, or reports a different chain ID.
 */
export async function createRPCAdapter(options: RPCAdapterOptions): Promise<IRPCAdapter> {
  validateOptions(options);
  const chain = chainFor(options.chainId, options.rpcUrl);
  const client = createPublicClient({ chain, transport: http(options.rpcUrl, { retryCount: 0 }) });

  let endpointChainId: number;
  try {
    endpointChainId = await retryRPC(() => client.getChainId());
  } catch (error) {
    throw error instanceof RPCAdapterError ? error : requestError("getChainId", options.chainId, error);
  }
  if (endpointChainId !== options.chainId) {
    throw new RPCAdapterError(
      "RPC_CHAIN_ID_MISMATCH",
      `RPC endpoint reports chain ${endpointChainId}, expected chain ${options.chainId}`,
      { operation: "getChainId", chainId: options.chainId },
    );
  }

  /**
   * Returns deployed bytecode at an address, or no code for an EOA/empty account.
   * @param address Address to inspect.
   * @returns Deployed bytecode, or `undefined` when no bytecode exists.
   * @throws {RPCAdapterError} If the RPC request fails.
   */
  async function getCode(address: Address): Promise<Hex | undefined> {
    try {
      return await retryRPC(() => client.getCode({ address }));
    } catch (error) {
      throw requestError("getCode", options.chainId, error);
    }
  }

  /**
   * Reads and decodes a view/pure contract function through the configured RPC.
   * @param parameters Contract address, ABI, function name, and arguments.
   * @param readOptions Optional contract-code verification settings.
   * @returns The decoded contract result.
   * @throws {RPCAdapterError} If verification or the RPC request fails.
   */
  async function readContract<T>(parameters: ReadContractParameters, readOptions?: RPCReadContractOptions): Promise<T> {
    try {
      if (readOptions?.verifyCode) {
        if (!parameters.address) {
          throw new RPCAdapterError("RPC_INVALID_CONFIGURATION", "Contract address is required when verifyCode is enabled", {
            operation: "readContract",
            chainId: options.chainId,
          });
        }
        const code = await getCode(getAddress(parameters.address));
        if (!code || code === "0x") {
          throw new RPCAdapterError("RPC_CONTRACT_NOT_FOUND", `No contract code found at ${parameters.address}`, {
            operation: "readContract",
            chainId: options.chainId,
          });
        }
      }
      return await retryRPC(() => client.readContract(parameters)) as T;
    } catch (error) {
      if (error instanceof RPCAdapterError) throw error;
      throw requestError("readContract", options.chainId, error);
    }
  }

  return {
    readContract,
    getCode,
  };
}
