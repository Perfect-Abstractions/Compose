/** Configuration used to bind an adapter to one RPC endpoint and chain. */
export type RPCAdapterOptions = {
  /** HTTP or HTTPS JSON-RPC endpoint. */
  rpcUrl: string;
  /** Expected EVM chain ID reported by the endpoint. */
  chainId: number;
};
