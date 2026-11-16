import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  runCommandCaptureStdout: vi.fn(),
}));

vi.mock("../../../../src/utils/exec", () => ({
  runCommandCaptureStdout: mocks.runCommandCaptureStdout,
}));

import { hardhatAdapter } from "../../../../src/adapters/IFrameworkAdapter/hardhatAdapter/adapter";
import { listHardhatSignerAddresses } from "../../../../src/adapters/IFrameworkAdapter/hardhatAdapter/accounts";

let projectRoot: string;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-hardhat-accounts-"));
  mocks.runCommandCaptureStdout.mockReset();
  await fs.writeFile(path.join(projectRoot, "package.json"), JSON.stringify({
    devDependencies: {
      hardhat: "^3.8.0",
      "@nomicfoundation/hardhat-toolbox-viem": "^5.0.0",
    },
  }), "utf8");
});

afterEach(async () => {
  vi.restoreAllMocks();
  await fs.rm(projectRoot, { recursive: true, force: true });
});

describe("Hardhat account helpers", () => {
  it("lists the configured signer addresses from the managed probe", async () => {
    const address = "0x00000000000000000000000000000000000000a1";
    mocks.runCommandCaptureStdout.mockResolvedValue(
      `COMPOSE_ACCOUNT_ADDRESSES:["${address}"]\n`,
    );

    await expect(listHardhatSignerAddresses({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
    })).resolves.toEqual(["0x00000000000000000000000000000000000000A1"]);

    expect(mocks.runCommandCaptureStdout).toHaveBeenCalledWith(
      "npx",
      ["hardhat", "--build-profile", "production", "run", "--no-compile", ".compose/hardhat/account-probe.ts", "--network", "local"],
      expect.objectContaining({
        cwd: projectRoot,
        env: { COMPOSE_DEPLOY_RPC_URL: "http://127.0.0.1:8545" },
        forwardStdout: false,
      }),
    );
  });

  it("writes the probe under the ignored Compose runtime directory", async () => {
    mocks.runCommandCaptureStdout.mockResolvedValue(
      'COMPOSE_ACCOUNT_ADDRESSES:["0x00000000000000000000000000000000000000a1"]\n',
    );

    await listHardhatSignerAddresses({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
    });

    await expect(
      fs.readdir(path.join(projectRoot, ".compose", "hardhat")),
    ).resolves.toEqual(["account-probe.ts"]);
    await expect(fs.access(path.join(projectRoot, "scripts"))).rejects.toThrow();

    const gitignore = await fs.readFile(path.join(projectRoot, ".gitignore"), "utf8");
    expect(gitignore).toBe(".compose/\n");

    const probe = await fs.readFile(
      path.join(projectRoot, ".compose", "hardhat", "account-probe.ts"),
      "utf8",
    );
    expect(probe).toContain('network: "local"');
    expect(probe).toContain("actualChainId !== 31337");
    expect(probe).toContain("getWalletClients");
    expect(probe).not.toContain("{{");
  });

  it("keeps the ignored runtime directory stable across runs", async () => {
    mocks.runCommandCaptureStdout.mockResolvedValue(
      'COMPOSE_ACCOUNT_ADDRESSES:["0x00000000000000000000000000000000000000a1"]\n',
    );

    await fs.writeFile(path.join(projectRoot, ".gitignore"), "node_modules/\n.compose/\n", "utf8");

    await listHardhatSignerAddresses({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
    });
    await listHardhatSignerAddresses({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
    });

    const gitignore = await fs.readFile(path.join(projectRoot, ".gitignore"), "utf8");
    expect(gitignore).toBe("node_modules/\n.compose/\n");
    await expect(
      fs.readdir(path.join(projectRoot, ".compose", "hardhat")),
    ).resolves.toEqual(["account-probe.ts"]);
  });

  it("resolves a selected Compose account without listing network signers", async () => {
    await expect(hardhatAdapter.resolveDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: {
        alias: "deployer",
        address: "0x00000000000000000000000000000000000000a1",
      },
      passthrough: [],
    })).resolves.toBe("0x00000000000000000000000000000000000000A1");
    expect(mocks.runCommandCaptureStdout).not.toHaveBeenCalled();
  });

  it("resolves the first configured Hardhat signer by default", async () => {
    mocks.runCommandCaptureStdout.mockResolvedValue(
      'COMPOSE_ACCOUNT_ADDRESSES:["0x00000000000000000000000000000000000000a1","0x00000000000000000000000000000000000000a2"]\n',
    );

    await expect(hardhatAdapter.resolveDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: null,
      passthrough: [],
    })).resolves.toBe("0x00000000000000000000000000000000000000A1");
  });

  it("leaves the probe in place when Hardhat fails", async () => {
    mocks.runCommandCaptureStdout.mockRejectedValue(new Error("hardhat failed"));

    await expect(listHardhatSignerAddresses({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
    })).rejects.toThrow("hardhat failed");

    await expect(
      fs.readdir(path.join(projectRoot, ".compose", "hardhat")),
    ).resolves.toEqual(["account-probe.ts"]);
    await expect(fs.access(path.join(projectRoot, "scripts"))).rejects.toThrow();
  });

  it("rejects a response without the Compose marker", async () => {
    mocks.runCommandCaptureStdout.mockResolvedValue("no marker here\n");

    await expect(listHardhatSignerAddresses({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
    })).rejects.toThrow("Hardhat did not report its configured signer addresses.");
  });

  it("reports that Hardhat has no native account store or Compose-driven import", async () => {
    expect(hardhatAdapter.supportsAccountImport).toBe(false);
    await expect(hardhatAdapter.readAccountAddress(projectRoot, "deployer")).resolves.toEqual({
      address: null,
      exists: false,
      requiresUnlock: false,
    });
    await expect(hardhatAdapter.resolveAccountAddress(projectRoot, "deployer")).resolves.toEqual({
      address: null,
      exists: false,
      requiresUnlock: false,
    });
    await expect(hardhatAdapter.importAccount(projectRoot, "deployer")).rejects.toThrow(
      "Hardhat accounts are configured in hardhat.config.ts; Compose does not import keys.",
    );
  });
});
