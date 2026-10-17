import type { Hex } from "viem";
import type { IHashingAdapter } from "../../adapters/IHashingAdapter/interface";
import type { DeployPlan } from "./types";

/** A plan without its hash, ready for canonical serialization. */
export type HashablePlan = Omit<DeployPlan, "planHash">;

/**
 * Serializes the deployment target and desired composition as canonical JSON.
 *
 * Facets are sorted by name so reordering registrations does not change the
 * hash, while every other field is included verbatim so drift in the target
 * chain, diamond, or facet set produces a new hash. Observed state (the
 * existing lock record and its diff) is intentionally excluded.
 */
export function canonicalPlanJson(plan: HashablePlan): string {
  const facets = [...plan.facets]
    .map((facet) => ({
      contract: facet.contractName,
      name: facet.name,
      source: facet.sourcePath,
    }))
    .sort((left, right) => (left.name < right.name ? -1 : left.name > right.name ? 1 : 0));

  return JSON.stringify({
    chain: { chainId: plan.chain.chainId, key: plan.chain.chainKey, rpcUrl: plan.chain.rpcUrl },
    diamond: {
      contract: plan.diamond.contractName,
      name: plan.diamondName,
      source: plan.diamond.sourcePath,
    },
    facets,
    framework: plan.framework,
    instance: plan.instance,
  });
}

/** Computes the plan hash used to bind generated scripts to a plan. */
export function computePlanHash(plan: HashablePlan, hashing: IHashingAdapter): Hex {
  return hashing.keccak256(canonicalPlanJson(plan));
}
