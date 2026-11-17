import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { IFrameworkAdapter } from "../../../src/adapters/IFrameworkAdapter/interface";
import { Context } from "../../../src/context/context";
import type { ComposeContext, ModuleState } from "../../../src/context/types";
import { AccountModule } from "../../../src/modules/accounts/module";
import type { AccountActionResult } from "../../../src/modules/accounts/types";

let projectRoot: string;
let ctx: ComposeContext;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-account-module-"));
  ctx = Context.create();
  ctx.param.projectRoot = projectRoot;
  vi.spyOn(console, "log").mockImplementation(() => {});
  await fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify({
    framework: "foundry",
    accounts: {
      deployer: {
        address: "0x00000000000000000000000000000000000000a1",
        foundry: { account: "deployer" },
      },
    },
    chains: {
      local: { rpc: "http://127.0.0.1:8545", chainId: 31337, account: "deployer" },
    },
  }), "utf8");
});

afterEach(async () => {
  vi.restoreAllMocks();
  await fs.rm(projectRoot, { recursive: true, force: true });
});

describe("AccountModule", () => {
  it("checks an account through the pipeline-provided adapter", async () => {
    const listSignerAddresses = vi.fn(async () => [
      "0x00000000000000000000000000000000000000A1",
    ]);
    const adapter = { listSignerAddresses } as unknown as IFrameworkAdapter;
    ctx.param.action = "check";
    ctx.param.accountName = "deployer";

    const project = await AccountModule.loadProject(ctx);
    await AccountModule.execute(ctx, project, { framework: "foundry", adapter });

    const state = ctx.state.account as ModuleState<AccountActionResult>;
    expect(state.result).toEqual({
      action: "check",
      alias: "deployer",
      address: "0x00000000000000000000000000000000000000A1",
      chainKey: "local",
    });
    expect(listSignerAddresses).toHaveBeenCalledWith(expect.objectContaining({
      projectRoot,
      chainKey: "local",
      accountName: "deployer",
    }));
  });
});
