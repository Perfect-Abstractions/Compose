import { beforeEach, describe, expect, it, vi } from "vitest";
import type { IFrameworkAdapter } from "../../../src/adapters/IFrameworkAdapter/interface";
import { Context } from "../../../src/context/context";
import type { ModuleState } from "../../../src/context/types";
import { DeploySimulationModule } from "../../../src/modules/deploySimulation/module";
import type { DeployPlan } from "../../../src/modules/deployPlan/types";

const mocks = vi.hoisted(() => ({ runCommand: vi.fn(async () => {}) }));
vi.mock("../../../src/utils/exec", () => ({ runCommand: mocks.runCommand }));

const plan: DeployPlan = {
  mode: "fresh",
  framework: "foundry",
  projectRoot: "/tmp/compose-project",
  composeJsonPath: "/tmp/compose-project/compose.json",
  diamondName: "ExampleDiamond",
  diamond: { contractName: "Diamond", sourcePath: "", importSpec: "" },
  instance: "default",
  chain: { chainKey: "sepolia", rpcUrl: "https://rpc.example.test", chainId: 11155111 },
  rpcUrlOverridden: false,
  account: null,
  facets: [],
  existing: null,
  diff: null,
  upgradeable: false,
  planHash: `0x${"ab".repeat(32)}`,
};

beforeEach(() => {
  mocks.runCommand.mockReset().mockResolvedValue(undefined);
});

describe("DeploySimulationModule.simulate", () => {
  it("invokes the framework in simulation mode at the pinned fork block", async () => {
    const ctx = Context.create();
    const createDeployCommand = vi.fn(() => ({ command: "forge", args: [] }));
    const adapter = { createDeployCommand } as unknown as IFrameworkAdapter;

    await DeploySimulationModule.simulate(ctx, plan, "/tmp/ComposeDeploy.s.sol", adapter, 1234n, null);

    expect(createDeployCommand).toHaveBeenCalledWith({
      chainId: 11155111,
      chainKey: "sepolia",
      passthrough: [],
      projectRoot: "/tmp/compose-project",
      rpcUrl: "https://rpc.example.test",
      account: null,
      scriptPath: "/tmp/ComposeDeploy.s.sol",
      runnerPath: null,
      mode: "simulate",
      forkBlockNumber: 1234n,
    });
    const state = ctx.state.deploySimulation as ModuleState<{ forkBlockNumber: bigint }>;
    expect(state.success).toBe(true);
    expect(state.result?.forkBlockNumber).toBe(1234n);
    expect(mocks.runCommand).toHaveBeenCalledWith("forge", [], { cwd: plan.projectRoot });
  });

  it("records failed simulations and rethrows the framework error", async () => {
    const ctx = Context.create();
    mocks.runCommand.mockRejectedValueOnce(new Error("Simulated revert"));
    const adapter = { createDeployCommand: () => ({ command: "forge", args: [] }) } as unknown as IFrameworkAdapter;

    await expect(
      DeploySimulationModule.simulate(ctx, plan, "/tmp/ComposeDeploy.s.sol", adapter, 1234n, null),
    ).rejects.toThrow("Simulated revert");
    const state = ctx.state.deploySimulation as ModuleState<unknown>;
    expect(state.success).toBe(false);
    expect(state.error?.code).toBe("DEPLOY_SIMULATION_FAILED");
  });
});
