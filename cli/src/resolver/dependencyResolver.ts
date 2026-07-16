import {
  DependencyMap,
  DependencyParams,
  DependencyRegistry,
} from "./dependencyRegistry";
import { DependencyKey } from "./dependencyKey";

/** A request for a specific dependency, optionally with parameters. */
export type DependencyRequest = {
  key: DependencyKey;
  params?: DependencyParams;
};

/**
 * Resolves adapter dependencies requested by pipelines.
 *
 * Accepts an array of {@link DependencyRequest} objects, looks up each key in
 * the {@link DependencyRegistry}, invokes the factory, and collects the results
 * into a partial {@link DependencyMap}.
 */
export const DependencyResolver = {
  /**
   * Resolves the requested adapter dependencies from the registry.
   *
   * Iterates over each request, retrieves the factory from the registry, and
   * invokes it (passing optional params). Throws if a factory is not found for
   * a given key.
   *
   * @param requests - Array of dependency requests specifying which adapters to resolve.
   * @returns A partial map of resolved dependencies keyed by {@link DependencyKey}.
   */
  async resolve(
    requests: DependencyRequest[],
  ): Promise<Partial<DependencyMap>> {
    const deps: Partial<DependencyMap> = {};

    for (const request of requests) {
      const factory = DependencyRegistry[request.key];

      if (!factory) {
        throw new Error(`Dependency factory not found: ${request.key}`);
      }

      deps[request.key] = await factory(request.params) as any;
    }

    return deps;
  },
};
