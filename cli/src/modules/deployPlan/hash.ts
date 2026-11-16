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
 * chain, diamond, or facet set produces a new hash. Source identity comes from
 * the artifact-facing import specifier, not the absolute source path: checkouts
 * and CI workspaces live at different paths, but the same project must produce
 * the same plan.
 *
 * Observed state (the existing lock record and its diff) is intentionally
 * excluded, as are the RPC endpoint and selected signer: those are access and
 * execution configuration, not part of the deployment identity. Execution
 * still resolves the effective signer (including a framework default) before
 * running, validates the reported deployer against it, and scopes the Hardhat
 * Ignition deployment ID to it.
 */
export function canonicalPlanJson(plan: HashablePlan): string {
  const facets = [...plan.facets]
    .map((facet) => ({
      contract: facet.contractName,
      name: facet.name,
      importSpec: facet.importSpec,
    }))
    .sort((left, right) => (left.name < right.name ? -1 : left.name > right.name ? 1 : 0));

  return JSON.stringify({
    chain: { chainId: plan.chain.chainId, key: plan.chain.chainKey },
    diamond: {
      contract: plan.diamond.contractName,
      name: plan.diamondName,
      importSpec: plan.diamond.importSpec,
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
