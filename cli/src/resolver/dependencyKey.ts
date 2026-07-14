/**
 * Type-safe keys for resolver dependencies.
 *
 * Each key maps to a specific adapter factory in the {@link DependencyRegistry}
 * and a typed result in the {@link DependencyMap}.
 */
export enum DependencyKey {
  Hashing = "hashing",
  Foundry = "foundry",
  Hardhat = "hardhat",
}
