import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  runCommandCaptureStdout: vi.fn(),
  isInteractive: vi.fn(() => false),
  confirm: vi.fn(async () => true),
}));

vi.mock("../../src/utils/exec", () => ({ runCommandCaptureStdout: mocks.runCommandCaptureStdout }));
vi.mock("../../src/utils/inquirer", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../src/utils/inquirer")>();
  return {
    ...actual,
    isInteractive: mocks.isInteractive,
    loadPrompts: async () => ({ confirm: mocks.confirm, input: vi.fn() }),
  };
});

import { Context } from "../../src/context/context";
import { AccountPipeline } from "../../src/pipelines/accountPipeline";

let projectRoot: string;
let ctx: ReturnType<typeof Context.create>;

beforeEach(async () => {
  mocks.runCommandCaptureStdout.mockReset();
  mocks.isInteractive.mockReset().mockReturnValue(false);
  mocks.confirm.mockReset().mockResolvedValue(true);
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-accounts-"));
  vi.spyOn(os, "homedir").mockReturnValue(projectRoot);
  ctx = Context.create();
  ctx.param.projectRoot = projectRoot;
  await fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify({
    framework: "foundry",
    accounts: {},
    chains: { local: { rpc: "http://127.0.0.1:8545", chainId: 31337 } },
  }), "utf8");
});

afterEach(async () => {
  vi.restoreAllMocks();
  await fs.rm(projectRoot, { recursive: true, force: true });
});

async function readComposeJson(): Promise<Record<string, unknown>> {
  return JSON.parse(await fs.readFile(path.join(projectRoot, "compose.json"), "utf8")) as Record<string, unknown>;
}

describe("AccountPipeline", () => {
  it("registers a public address and optional chain default without storing credentials", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    ctx.param.action = "setup";
    ctx.param.accountName = "deployer";
    ctx.param.address = "0x00000000000000000000000000000000000000a1";
    ctx.param.foundryAccount = "mainnet-deployer";
    ctx.param.chain = "local";

    await AccountPipeline.execute(ctx);

    const composeJson = await readComposeJson();
    expect(composeJson.accounts).toEqual({
      deployer: {
        address: "0x00000000000000000000000000000000000000A1",
        foundry: { account: "mainnet-deployer" },
      },
    });
    expect(composeJson.chains).toEqual({
      local: { rpc: "http://127.0.0.1:8545", chainId: 31337, account: "deployer" },
    });
    expect(JSON.stringify(composeJson)).not.toContain("privateKey");
    expect(log.mock.calls.flat().join("\n")).toContain(
      "Import it into Foundry's keystore before deploying with 'cast wallet import mainnet-deployer'.",
    );
  });

  it("delegates Foundry key entry to cast's interactive keystore prompt", async () => {
    const nativeAccount = "test-deployer";
    const address = "0x00000000000000000000000000000000000000a1";
    mocks.isInteractive.mockReturnValue(true);
    mocks.runCommandCaptureStdout.mockImplementation(async (command, args) => {
      expect(command).toBe("cast");
      expect(args).toEqual(["wallet", "import", nativeAccount, "--interactive"]);
      const keystoreDirectory = path.join(projectRoot, ".foundry", "keystores");
      await fs.mkdir(keystoreDirectory, { recursive: true });
      await fs.writeFile(path.join(keystoreDirectory, nativeAccount), "{}", "utf8");
      return `\n${nativeAccount} keystore was saved successfully. Address: ${address}\n`;
    });
    ctx.param.action = "setup";
    ctx.param.accountName = "deployer";
    ctx.param.foundryAccount = nativeAccount;
    const log = vi.spyOn(console, "log").mockImplementation(() => {});

    await AccountPipeline.execute(ctx);

    expect(mocks.runCommandCaptureStdout).toHaveBeenCalledOnce();
    expect((await readComposeJson()).accounts).toEqual({
      deployer: {
        address: "0x00000000000000000000000000000000000000A1",
        foundry: { account: nativeAccount },
      },
    });
    expect(log.mock.calls.flat().join("\n")).not.toContain("Use 'cast wallet import'");
    expect(log.mock.calls.flat().join("\n")).not.toContain("Import it into Foundry's keystore");
  });

  it("unlocks an existing Foundry keystore to resolve its address without importing again", async () => {
    const nativeAccount = "sepolia-deployer";
    const address = "0x8836442b6b4843ba1f077406cc82fddb0f3d16ef";
    const keystoreDirectory = path.join(projectRoot, ".foundry", "keystores");
    await fs.mkdir(keystoreDirectory, { recursive: true });
    await fs.writeFile(
      path.join(keystoreDirectory, nativeAccount),
      JSON.stringify({ crypto: {}, id: "test-id", version: 3 }),
      "utf8",
    );
    mocks.isInteractive.mockReturnValue(true);
    mocks.runCommandCaptureStdout.mockImplementation(async (command, args, options) => {
      expect(command).toBe("cast");
      expect(args).toEqual(["wallet", "address", "--account", nativeAccount]);
      expect(options).toEqual({ cwd: projectRoot, forwardStdout: false });
      return `${address}\n`;
    });
    ctx.param.action = "setup";
    ctx.param.accountName = nativeAccount;
    ctx.param.chain = "local";
    const log = vi.spyOn(console, "log").mockImplementation(() => {});

    await AccountPipeline.execute(ctx);

    expect(mocks.runCommandCaptureStdout).toHaveBeenCalledOnce();
    expect(mocks.confirm).not.toHaveBeenCalled();
    expect(log.mock.calls.flat().join("\n")).not.toContain("Import it into Foundry's keystore");
    expect((await readComposeJson()).accounts).toEqual({
      [nativeAccount]: {
        address: "0x8836442b6B4843BA1f077406cC82FddB0F3D16eF",
        foundry: { account: nativeAccount },
      },
    });
  });

  it("requires a public address for an existing encrypted Foundry keystore in non-interactive setup", async () => {
    const nativeAccount = "sepolia-deployer";
    const keystoreDirectory = path.join(projectRoot, ".foundry", "keystores");
    await fs.mkdir(keystoreDirectory, { recursive: true });
    await fs.writeFile(
      path.join(keystoreDirectory, nativeAccount),
      JSON.stringify({ crypto: {}, id: "test-id", version: 3 }),
      "utf8",
    );
    ctx.param.action = "setup";
    ctx.param.accountName = nativeAccount;

    await expect(AccountPipeline.execute(ctx)).rejects.toThrow(
      "already exists, but its address is encrypted. Run setup interactively, set ETH_PASSWORD to a Foundry password-file path, or pass its public address with --address.",
    );

    expect(mocks.runCommandCaptureStdout).not.toHaveBeenCalled();
    expect(mocks.confirm).not.toHaveBeenCalled();
  });

  it("rejects an unknown chain before prompting for or importing a Foundry key", async () => {
    mocks.isInteractive.mockReturnValue(true);
    ctx.param.action = "setup";
    ctx.param.accountName = "sepolia-deployer";
    ctx.param.chain = "sepolia";

    await expect(AccountPipeline.execute(ctx)).rejects.toThrow(
      "Chain 'sepolia' was not found in compose.json.",
    );

    expect(mocks.confirm).not.toHaveBeenCalled();
    expect(mocks.runCommandCaptureStdout).not.toHaveBeenCalled();
    expect(await readComposeJson()).toEqual({
      framework: "foundry",
      accounts: {},
      chains: { local: { rpc: "http://127.0.0.1:8545", chainId: 31337 } },
    });
  });

  it("lists registered aliases and chain defaults", async () => {
    await fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify({
      framework: "hardhat",
      accounts: { deployer: { address: "0x00000000000000000000000000000000000000a1" } },
      chains: { local: { rpc: "http://127.0.0.1:8545", chainId: 31337, account: "deployer" } },
    }), "utf8");
    ctx.param.action = "list";
    const log = vi.spyOn(console, "log").mockImplementation(() => {});

    await AccountPipeline.execute(ctx);

    expect(log.mock.calls.flat().join("\n")).toContain("deployer");
    expect(log.mock.calls.flat().join("\n")).toContain("Default for local: deployer");
  });

  it("checks a Foundry alias against its native keystore address", async () => {
    vi.spyOn(os, "homedir").mockReturnValue(projectRoot);
    const keystoreDirectory = path.join(projectRoot, ".foundry", "keystores");
    await fs.mkdir(keystoreDirectory, { recursive: true });
    await fs.writeFile(
      path.join(keystoreDirectory, "deployer"),
      JSON.stringify({ address: "00000000000000000000000000000000000000a1" }),
      "utf8",
    );
    await fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify({
      framework: "foundry",
      accounts: {
        deployer: {
          address: "0x00000000000000000000000000000000000000a1",
          foundry: { account: "deployer" },
        },
      },
      chains: { local: { rpc: "http://127.0.0.1:8545", chainId: 31337, account: "deployer" } },
    }), "utf8");
    ctx.param.action = "check";
    ctx.param.accountName = "deployer";
    const log = vi.spyOn(console, "log").mockImplementation(() => {});

    await AccountPipeline.execute(ctx);

    expect(log.mock.calls.flat().join("\n")).toContain("Account 'deployer' is available on local");
  });

  it("checks a Hardhat alias against configured network signers", async () => {
    const address = "0x00000000000000000000000000000000000000a1";
    await fs.writeFile(path.join(projectRoot, "package.json"), JSON.stringify({
      devDependencies: {
        hardhat: "^3.8.0",
        "@nomicfoundation/hardhat-toolbox-viem": "^5.0.0",
      },
    }), "utf8");
    await fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify({
      framework: "hardhat",
      accounts: { deployer: { address } },
      chains: { local: { rpc: "http://127.0.0.1:8545", chainId: 31337, account: "deployer" } },
    }), "utf8");
    mocks.runCommandCaptureStdout.mockResolvedValue(
      `COMPOSE_ACCOUNT_ADDRESSES:["${address}"]\n`,
    );
    ctx.param.action = "check";
    ctx.param.accountName = "deployer";
    const log = vi.spyOn(console, "log").mockImplementation(() => {});

    await AccountPipeline.execute(ctx);

    expect(mocks.runCommandCaptureStdout).toHaveBeenCalledWith(
      "npx",
      expect.arrayContaining(["hardhat", "run", "--network", "local"]),
      expect.objectContaining({
        cwd: projectRoot,
        env: { COMPOSE_DEPLOY_RPC_URL: "http://127.0.0.1:8545" },
      }),
    );
    expect(log.mock.calls.flat().join("\n")).toContain("Account 'deployer' is available on local");
    expect(await fs.readdir(path.join(projectRoot, "scripts"))).toEqual([]);
  });

  it("removes only the Compose alias and clears its chain defaults", async () => {
    await fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify({
      framework: "foundry",
      accounts: {
        deployer: {
          address: "0x00000000000000000000000000000000000000a1",
          foundry: { account: "deployer" },
        },
      },
      chains: { local: { rpc: "http://127.0.0.1:8545", chainId: 31337, account: "deployer" } },
    }), "utf8");
    ctx.param.action = "remove";
    ctx.param.accountName = "deployer";

    await AccountPipeline.execute(ctx);

    const composeJson = await readComposeJson();
    expect(composeJson.accounts).toEqual({});
    expect(composeJson.chains).toEqual({
      local: { rpc: "http://127.0.0.1:8545", chainId: 31337 },
    });
  });
});
