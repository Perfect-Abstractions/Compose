import { describe, expect, it } from "vitest";
import { HashingAdapter } from "../../../src/adapters/IHashingAdapter/adapter";
import { canonicalPlanJson, computePlanHash, type HashablePlan } from "../../../src/modules/deployPlan/hash";

function basePlan(): HashablePlan {
  return {
    mode: "fresh",
    framework: "foundry",
    projectRoot: "/tmp/project",
    composeJsonPath: "/tmp/project/compose.json",
    diamondName: "CounterDiamond",
    diamond: {
      contractName: "Diamond",
      sourcePath: "/tmp/project/src/Diamond.sol",
      importSpec: "../src/Diamond.sol",
    },
    instance: "default",
    chain: { chainKey: "local", rpcUrl: "http://127.0.0.1:8545", chainId: 31337 },
    rpcUrlOverridden: false,
    account: null,
    facets: [
      {
        name: "AlphaFacet",
        contractName: "AlphaFacet",
        sourcePath: "/tmp/project/src/AlphaFacet.sol",
        importSpec: "../src/AlphaFacet.sol",
      },
      {
        name: "BetaFacet",
        contractName: "BetaFacet",
        sourcePath: "/tmp/project/src/BetaFacet.sol",
        importSpec: "../src/BetaFacet.sol",
      },
    ],
    existing: null,
    diff: null,
    upgradeable: false,
  };
}

describe("canonicalPlanJson", () => {
  it("sorts facets by name regardless of registration order", () => {
    const plan = basePlan();
    const reordered = { ...plan, facets: [...plan.facets].reverse() };
    expect(canonicalPlanJson(reordered)).toBe(canonicalPlanJson(plan));
  });

  it("excludes observed state such as the existing record and the diff", () => {
    const plan = basePlan();
    const observed: HashablePlan = {
      ...plan,
      mode: "redeploy",
      diff: { added: ["GammaFacet"], removed: ["BetaFacet"] },
      existing: {
        diamond: "0x00000000000000000000000000000000000000aa",
        facets: { AlphaFacet: "0x00000000000000000000000000000000000000b1" },
        facetHash: `0x${"11".repeat(32)}`,
        lastSync: "2026-01-01T00:00:00.000Z",
        txHash: `0x${"22".repeat(32)}`,
      },
    };
    expect(canonicalPlanJson(observed)).toBe(canonicalPlanJson(plan));
  });
});

describe("computePlanHash", () => {
  it("is stable across facet registration order", () => {
    const plan = basePlan();
    const reordered = { ...plan, facets: [...plan.facets].reverse() };
    expect(computePlanHash(reordered, HashingAdapter)).toBe(
      computePlanHash(plan, HashingAdapter),
    );
  });

  it("changes when the facet set changes", () => {
    const plan = basePlan();
    const added = {
      ...plan,
      facets: [
        ...plan.facets,
        {
          name: "GammaFacet",
          contractName: "GammaFacet",
          sourcePath: "/tmp/project/src/GammaFacet.sol",
          importSpec: "../src/GammaFacet.sol",
        },
      ],
    };
    expect(computePlanHash(added, HashingAdapter)).not.toBe(
      computePlanHash(plan, HashingAdapter),
    );
  });

  it("changes when the chain or instance changes", () => {
    const plan = basePlan();
    const otherChain = { ...plan, chain: { ...plan.chain, rpcUrl: "http://127.0.0.1:9999" } };
    const otherInstance = { ...plan, instance: "staging" };
    expect(computePlanHash(otherChain, HashingAdapter)).not.toBe(
      computePlanHash(plan, HashingAdapter),
    );
    expect(computePlanHash(otherInstance, HashingAdapter)).not.toBe(
      computePlanHash(plan, HashingAdapter),
    );
  });

  it("produces a lowercase keccak256 hex digest", () => {
    expect(computePlanHash(basePlan(), HashingAdapter)).toMatch(/^0x[0-9a-f]{64}$/);
  });
});
