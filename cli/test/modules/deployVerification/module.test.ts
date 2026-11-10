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
const DIAMOND_TX = `0x${"33".repeat(32)}` as Hex;
const CODE = "0x600060005260206000f3" as Hex;

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

function stubDiamond(addresses: Address[]): IDiamondAdapter {
  return {
    facets: async () => [],
    facetAddresses: async () => addresses,
    facetFunctionSelectors: async () => [],
    facetAddress: async () => "0x0000000000000000000000000000000000000000",
  };
}

async function verify(
  rpc: IRPCAdapter,
  diamond: IDiamondAdapter,
  ignitionDeploymentId?: string,
): Promise<{ success: boolean; record: DiamondDeployment | null; message: string | null }> {
  const ctx = Context.create();
  const resolved = await DeployVerificationModule.verify(ctx, deployPlan(), executionResult(ignitionDeploymentId), {
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
      stubDiamond([getAddress(FACET_A), getAddress(FACET_B)]),
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
      stubDiamond([getAddress(FACET_A), getAddress(FACET_B)]),
      ignitionDeploymentId,
    );

    expect(outcome.success).toBe(true);
    expect(outcome.record?.ignitionDeploymentId).toBe(ignitionDeploymentId);
  });

  it("fails when the diamond has no code", async () => {
    const report = vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(
      stubRpc((address) => (address === DIAMOND ? undefined : CODE)),
      stubDiamond([FACET_A, FACET_B]),
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
      stubDiamond([FACET_A, FACET_B]),
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("No contract code found at facet 'BetaFacet'");
  });

  it("fails when the on-chain facet set differs from the result", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(
      stubRpc(() => CODE),
      stubDiamond([
        FACET_A,
        FACET_B,
        "0x00000000000000000000000000000000000000c3",
      ] as Address[]),
    );

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain("do not match the deployment result");
    expect(outcome.message).toContain("0x00000000000000000000000000000000000000c3");
  });

  it("fails when a reported facet is missing on-chain", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const outcome = await verify(stubRpc(() => CODE), stubDiamond([FACET_A]));

    expect(outcome.success).toBe(false);
    expect(outcome.message).toContain(FACET_B);
  });
});
