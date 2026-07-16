import {
  HashingAdapter,
} from "../adapters/hashingAdapter";
import { IHashingAdapter } from "../adapters/interface/IHashingAdapter";
import { IFrameworkAdapter } from "../adapters/interface/IFrameworkAdapter";
import { foundryAdapter } from "../adapters/foundryAdapter";
import { hardhatAdapter } from "../adapters/hardhatAdapter";
import { DependencyKey } from "./dependencyKey";

/** Optional parameters passed to a dependency factory. */
export type DependencyParams = Record<string, unknown>;

/** Factory function that creates or returns a dependency instance. */
export type DependencyFactory<T = unknown> = (
  params?: DependencyParams,
) => Promise<T> | T;

/** Typed map of all dependency keys to their resolved adapter types. */
export type DependencyMap = {
  [DependencyKey.Hashing]: IHashingAdapter;
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
  [DependencyKey.Foundry]: () => foundryAdapter,
  [DependencyKey.Hardhat]: () => hardhatAdapter,
};
