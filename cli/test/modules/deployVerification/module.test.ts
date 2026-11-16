import path from "node:path";
import { getAddress, type Address, type Hex } from "viem";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { IDiamondAdapter } from "../../../src/adapters/IDiamondAdapter/interface";
import { HashingAdapter } from "../../../src/adapters/IHashingAdapter/adapter";
import type { IRPCAdapter } from "../../../src/adapters/IRPCAdapter/interface";
import { Context } from "../../../src/context/context";
import type { ModuleState } from "../../../src/context/types";
import type { DeployExecutionResult } from "../../../src/modules/deployExecution/types";
import type { DeployPlan } from "../../../src/modules/deployPlan/types";
import { LockFileModule } from "../../../src/modules/lockFile/module";
import type { DiamondDeployment } from "../../../src/modules/lockFile/types";
import { DeployVerificationModule } from "../../../src/modules/deployVerification/module";

const DIAMOND = "0x00000000000000000000000000000000000000aa";
const FACET_A = "0x00000000000000000000000000000000000000b1";
const FACET_B = "0x00000000000000000000000000000000000000b2";
const SELECTOR_A1 = "0xaaaaaaaa" as Hex;
const SELECTOR_A2 = "0xbbbbbbbb" as Hex;
const SELECTOR_B = "0xcccccccc" as Hex;
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as Address;
const DIAMOND_TX = `0x${"33".repeat(32)}` as Hex;
const CODE = "0x600060005260206000f3" as Hex;

const DEFAULT_SELECTORS: Record<string, Hex[]> = {
  [FACET_A.toLowerCase()]: [SELECTOR_A1, SELECTOR_A2],
  [FACET_B.toLowerCase()]: [SELECTOR_B],
};

const DEFAULT_ROUTES: Record<string, Address> = {
  [SELECTOR_A1.toLowerCase()]: FACET_A as Address,
  [SELECTOR_A2.toLowerCase()]: FACET_A as Address,
  [SELECTOR_B.toLowerCase()]: FACET_B as Address,
};

function executionResult(ignitionDeploymentId?: string): DeployExecutionResult {
  return {
    diamond: DIAMOND,
    facets: { AlphaFacet: FACET_A, BetaFacet: FACET_B },
    ...(ignitionDeploymentId ? { ignitionDeploymentId } : {}),
    transactions: { diamond: DIAMOND_TX },
  };
}

function deployPlan(): DeployPlan {
  return {
    mode: "fresh",
    framework: "foundry",
    projectRoot: "/tmp/project",
    composeJsonPath: "/tmp/project/compose.json",
    diamondName: "CounterDiamond",
    diamond: {
      contractName: "Diamond",
      sourcePath: path.join("/tmp/project/src/Diamond.sol"),
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
    planHash: `0x${"cd".repeat(32)}` as Hex,
  };
}

function stubRpc(codeFor: (address: string) => Hex | undefined): IRPCAdapter {
  return {
    getBlockNumber: async () => 0n,
    readContract: async () => {
      throw new Error("readContract is not used by verification");
    },
    getCode: async (address: Address) => codeFor(address.toLowerCase()),
  };
}

type DiamondStubOptions = {
  addresses?: Address[];
  selectors?: Record<string, Hex[]>;
  routes?: Record<string, Address>;
};

function stubDiamond(options: DiamondStubOptions = {}): IDiamondAdapter {
  const addresses = options.addresses ?? [getAddress(FACET_A), getAddress(FACET_B)];
  const selectors = options.selectors ?? DEFAULT_SELECTORS;
  const routes = options.routes ?? DEFAULT_ROUTES;

  return {
    facets: async () => [],
    facetAddresses: async () => addresses,
    facetFunctionSelectors: async (_diamond, facet) => selectors[facet.toLowerCase()] ?? [],
    facetAddress: async (_diamond, selector) => routes[selector.toLowerCase()] ?? ZERO_ADDRESS,
  };
}

async function verify(
  rpc: IRPCAdapter,
  diamond: IDiamondAdapter,
  ignitionDeploymentId?: string,
  execution: DeployExecutionResult = executionResult(ignitionDeploymentId),
): Promise<{ success: boolean; record: DiamondDeployment | null; message: string | null }> {
  const ctx = Context.create();
  const resolved = await DeployVerificationModule.verify(ctx, deployPlan(), execution, {
    diamond,
    hashing: HashingAdapter,
    rpc,
  });
  const state = resolved.state.deployVerification as ModuleState<DiamondDeployment>;
  return { record: state?.result ?? null, success: state?.success ?? false, message: state?.error?.message ?? null };
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe("DeployVerificationModule.verify", () => {
  it("builds the lock record when chain state matches the result", async () => {
    const outcome = await verify(
      stubRpc(() => CODE),
      stubDiamond(),
    );

    expect(outcome.success).toBe(true);
    expect(outcome.record).toMatchObject({
      diamond: DIAMOND,
      facets: { AlphaFacet: FACET_A, BetaFacet: FACET_B },
      txHash: DIAMOND_TX,
    });
    expect(outcome.record?.facetHash).toBe(
      LockFileModule.computeFacetHash([FACET_A as Hex, FACET_B as Hex], HashingAdapter),
    );
    expect(Date.parse(outcome.record?.lastSync ?? "")).not.toBeNaN();
  });

  it("persists the Hardhat Ignition deployment ID in the verified lock record", async () => {
    const ignitionDeploymentId = "compose-counterdiamond-local-default-abcdef12";
    const outcome = await verify(
      stubRpc(() => CODE),
      stubDiamond(),
      ignitionDeploymentId,
    );

    expect(outcome.success).toBe(true);
    expect(outcome.record?.ignitionDeploymentId).toBe(ignitionDeploymentId);
  });

  it("fails when the diamond has no code", async () => {
    const report = vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(
      stubRpc((address) => (address === DIAMOND ? undefined : CODE)),
      stubDiamond(),
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("No contract code found at the diamond address");
    expect(report).toHaveBeenCalledWith(
      expect.stringContaining("On-chain verification failed"),
    );
  });

  it("fails when a facet has no code", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(
      stubRpc((address) => (address === FACET_B ? undefined : CODE)),
      stubDiamond(),
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("No contract code found at facet 'BetaFacet'");
  });

  it("fails when the on-chain facet set differs from the result", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(
      stubRpc(() => CODE),
      stubDiamond({
        addresses: [
          FACET_A,
          FACET_B,
          "0x00000000000000000000000000000000000000c3",
        ] as Address[],
      }),
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("do not match the deployment result");
    expect(outcome.message).toContain("0x00000000000000000000000000000000000000c3");
  });

  it("fails when a reported facet is missing on-chain", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(stubRpc(() => CODE), stubDiamond({ addresses: [FACET_A] }));

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain(FACET_B);
  });

  it("fails when two reported facets share an address", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const execution = executionResult();
    execution.facets = { AlphaFacet: FACET_A, BetaFacet: FACET_A };
    const outcome = await verify(stubRpc(() => CODE), stubDiamond(), undefined, execution);

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("Facets 'AlphaFacet' and 'BetaFacet' report the same address");
    expect(outcome.message).toContain("facet addresses must be unique");
  });

  it("fails when a reported facet address equals the diamond address", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const execution = executionResult();
    execution.facets = { AlphaFacet: DIAMOND, BetaFacet: FACET_B };
    const outcome = await verify(stubRpc(() => CODE), stubDiamond(), undefined, execution);

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("Facet 'AlphaFacet' uses the diamond address");
    expect(outcome.message).toContain("facets must be separate contracts");
  });

  it("fails when the on-chain facet list contains duplicates", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(
      stubRpc(() => CODE),
      stubDiamond({ addresses: [FACET_A, FACET_B, FACET_B] }),
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("The on-chain facet list contains duplicate address");
    expect(outcome.message).toContain(FACET_B);
  });

  it("fails when a facet exposes no selectors on the diamond", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(
      stubRpc(() => CODE),
      stubDiamond({
        selectors: {
          ...DEFAULT_SELECTORS,
          [FACET_B.toLowerCase()]: [],
        },
      }),
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("Facet 'BetaFacet'");
    expect(outcome.message).toContain("exposes no selectors");
  });

  it("fails when a selector routes to a different facet", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(
      stubRpc(() => CODE),
      stubDiamond({
        routes: {
          ...DEFAULT_ROUTES,
          [SELECTOR_B.toLowerCase()]: FACET_A as Address,
        },
      }),
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain(`Selector ${SELECTOR_B}`);
    expect(outcome.message).toContain("is routed to");
    expect(outcome.message).toContain(FACET_A);
  });

  it("fails when a selector is not routed by the diamond", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(
      stubRpc(() => CODE),
      stubDiamond({
        routes: {
          ...DEFAULT_ROUTES,
          [SELECTOR_A1.toLowerCase()]: ZERO_ADDRESS,
        },
      }),
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain(`Selector ${SELECTOR_A1}`);
    expect(outcome.message).toContain("is not routed by the diamond");
  });

  it("compares facet addresses case-insensitively", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const execution = executionResult();
    execution.facets = {
      AlphaFacet: FACET_A.toUpperCase().replace("0X", "0x") as Hex,
      BetaFacet: FACET_A,
    };
    const outcome = await verify(stubRpc(() => CODE), stubDiamond(), undefined, execution);

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("facet addresses must be unique");
  });
});
