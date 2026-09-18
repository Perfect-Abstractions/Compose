import {
  HashingAdapter,
} from "../adapters/IHashingAdapter/adapter";
import { IHashingAdapter } from "../adapters/IHashingAdapter/interface";
import { IFrameworkAdapter } from "../adapters/IFrameworkAdapter/interface";
import { foundryAdapter } from "../adapters/IFrameworkAdapter/foundryAdapter/adapter";
import { hardhatAdapter } from "../adapters/IFrameworkAdapter/hardhatAdapter/adapter";
import type { IRPCAdapter } from "../adapters/IRPCAdapter/interface";
import { createRPCAdapter } from "../adapters/IRPCAdapter/adapter";
import { resolveChainConfig } from "../utils/chainConfig";
import { DependencyKey } from "./dependencyKey";

/** Optional parameters passed to a dependency factory. */
export type DependencyParams = Record<string, unknown>;

type RPCDependencyParams = DependencyParams & {
  chainKey?: unknown;
  projectRoot?: string;
};

/** Factory function that creates or returns a dependency instance. */
export type DependencyFactory<T = unknown> = (
  params?: DependencyParams,
) => Promise<T> | T;

/** Typed map of all dependency keys to their resolved adapter types. */
export type DependencyMap = {
  [DependencyKey.Hashing]: IHashingAdapter;
  [DependencyKey.RPC]: IRPCAdapter;
  [DependencyKey.Foundry]: IFrameworkAdapter;
  [DependencyKey.Hardhat]: IFrameworkAdapter;
};

/**
 * Maps dependency keys to adapter factories.
 *
 * The registry is the single source of truth for which adapters are available
 * and how they are instantiated. Each entry is a factory function that returns
 * the corresponding adapter singleton or creates a new instance.
 *
 * Used by {@link DependencyResolver} to look up and invoke factories for
 * requested dependency keys.
 */
export const DependencyRegistry: {
  [Key in DependencyKey]: DependencyFactory<DependencyMap[Key]>;
} = {
  [DependencyKey.Hashing]: () => HashingAdapter,
  [DependencyKey.RPC]: async (params) => {
    const resolved = await resolveChainConfig(params as RPCDependencyParams | undefined);
    return createRPCAdapter({ rpcUrl: resolved.rpcUrl, chainId: resolved.chainId });
  },
  [DependencyKey.Foundry]: () => foundryAdapter,
  [DependencyKey.Hardhat]: () => hardhatAdapter,
};
