import {
  DependencyMap,
  DependencyParams,
  DependencyRegistry,
} from "./dependencyRegistry";
import { DependencyKey } from "./dependencyKey";

export type DependencyRequest = {
  key: DependencyKey;
  params?: DependencyParams;
};

export const DependencyResolver = {
  // Resolve only the adapter dependencies explicitly requested by the pipeline.
  async resolve(
    requests: DependencyRequest[],
  ): Promise<Partial<DependencyMap>> {
    const deps: Partial<DependencyMap> = {};

    for (const request of requests) {
      const factory = DependencyRegistry[request.key];

      if (!factory) {
        throw new Error(`Dependency factory not found: ${request.key}`);
      }

      deps[request.key] = await factory(request.params);
    }

    return deps;
  },
};
