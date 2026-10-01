import type { Address, Abi, Hex } from "viem";
import type { ReadContractParameters } from "viem";

/** Optional behavior for a contract read. */
export type RPCReadContractOptions = {
  /** Verify that bytecode exists at the target before reading. */
  verifyCode?: boolean;
};

/** Generic read-only RPC boundary used by CLI modules. */
export interface IRPCAdapter {
  /** Return the current block number so related reads can be pinned consistently. */
  getBlockNumber(): Promise<bigint>;

  /** Read a view or pure contract function and return its decoded value. */
  readContract<T>(
    parameters: ReadContractParameters<Abi>,
    options?: RPCReadContractOptions,
  ): Promise<T>;

  /** Return deployed bytecode, or undefined when the account has no code. */
  getCode(address: Address, blockNumber?: bigint): Promise<Hex | undefined>;
}
