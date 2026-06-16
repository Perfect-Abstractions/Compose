import {
  HashingAdapter,
  HashingAdapterInterface,
} from "../adapters/hashingAdapter";
import { DependencyKey } from "./dependencyKey";

export type DependencyParams = Record<string, unknown>;

export type DependencyFactory<T = unknown> = (
  params?: DependencyParams,
) => Promise<T> | T;

export type DependencyMap = {
  [DependencyKey.Hashing]: HashingAdapterInterface;
};

// Map dependency keys to adapter factories used by the resolver.
export const DependencyRegistry: {
  [Key in DependencyKey]: DependencyFactory<DependencyMap[Key]>;
} = {
  [DependencyKey.Hashing]: () => HashingAdapter,
};
