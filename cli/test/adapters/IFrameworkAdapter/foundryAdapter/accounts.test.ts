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

import {
  importFoundryAccount,
  listFoundrySignerAddresses,
  readFoundryAccount,
  resolveFoundryAccount,
  resolveFoundryDeploySigner,
} from "../../../../src/adapters/IFrameworkAdapter/foundryAdapter/accounts";

let projectRoot: string;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-foundry-accounts-"));
  vi.spyOn(os, "homedir").mockReturnValue(projectRoot);
  mocks.runCommandCaptureStdout.mockReset();
});

afterEach(async () => {
  vi.restoreAllMocks();
  await fs.rm(projectRoot, { recursive: true, force: true });
});

async function writeKeystore(name: string, value: unknown): Promise<void> {
  const directory = path.join(projectRoot, ".foundry", "keystores");
  await fs.mkdir(directory, { recursive: true });
  await fs.writeFile(path.join(directory, name), JSON.stringify(value), "utf8");
}

describe("Foundry account helpers", () => {
  it("reads a plaintext address from a keystore", async () => {
    await writeKeystore("deployer", { address: "00000000000000000000000000000000000000a1" });

    await expect(readFoundryAccount("deployer")).resolves.toEqual({
      address: "0x00000000000000000000000000000000000000A1",
      exists: true,
      requiresUnlock: false,
    });
    expect(mocks.runCommandCaptureStdout).not.toHaveBeenCalled();
  });

  it("falls back to the .json keystore filename", async () => {
    await writeKeystore("deployer.json", { address: "0x00000000000000000000000000000000000000a1" });

    await expect(readFoundryAccount("deployer")).resolves.toMatchObject({
      address: "0x00000000000000000000000000000000000000A1",
      exists: true,
    });
  });

  it("reports a missing keystore without unlocking", async () => {
    await expect(readFoundryAccount("missing")).resolves.toEqual({
      address: null,
      exists: false,
      requiresUnlock: false,
    });
    expect(mocks.runCommandCaptureStdout).not.toHaveBeenCalled();
  });

  it("marks an encrypted keystore as requiring an unlock", async () => {
    await writeKeystore("deployer", { crypto: {}, id: "test-id", version: 3 });

    await expect(readFoundryAccount("deployer")).resolves.toEqual({
      address: null,
      exists: true,
      requiresUnlock: true,
    });
    expect(mocks.runCommandCaptureStdout).not.toHaveBeenCalled();
  });

  it("wraps keystore parse errors with the file path", async () => {
    const directory = path.join(projectRoot, ".foundry", "keystores");
    await fs.mkdir(directory, { recursive: true });
    await fs.writeFile(path.join(directory, "broken"), "{not json", "utf8");

    await expect(readFoundryAccount("broken")).rejects.toThrow("Unable to read Foundry keystore at");
  });

  it("does not unlock an encrypted keystore unless allowed", async () => {
    await writeKeystore("deployer", { crypto: {} });

    await expect(resolveFoundryAccount("deployer", projectRoot)).resolves.toEqual({
      address: null,
      exists: true,
      requiresUnlock: true,
    });
    expect(mocks.runCommandCaptureStdout).not.toHaveBeenCalled();
  });

  it("unlocks through cast and notifies the caller first", async () => {
    await writeKeystore("deployer", { crypto: {} });
    mocks.runCommandCaptureStdout.mockResolvedValue("0x00000000000000000000000000000000000000a1\n");
    const onUnlock = vi.fn();

    await expect(
      resolveFoundryAccount("deployer", projectRoot, { allowUnlock: true, onUnlock }),
    ).resolves.toEqual({
      address: "0x00000000000000000000000000000000000000A1",
      exists: true,
      requiresUnlock: false,
    });
    expect(onUnlock).toHaveBeenCalledOnce();
    expect(mocks.runCommandCaptureStdout).toHaveBeenCalledWith(
      "cast",
      ["wallet", "address", "--account", "deployer"],
      { cwd: projectRoot, forwardStdout: false },
    );
  });

  it("rejects an invalid cast address response", async () => {
    await writeKeystore("deployer", { crypto: {} });
    mocks.runCommandCaptureStdout.mockResolvedValue("no address here");

    await expect(
      resolveFoundryAccount("deployer", projectRoot, { allowUnlock: true }),
    ).rejects.toThrow("Foundry did not return a public address for keystore account 'deployer'.");
  });

  it("lists the resolved signer address", async () => {
    await writeKeystore("deployer", { address: "00000000000000000000000000000000000000a1" });

    await expect(listFoundrySignerAddresses({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      accountName: "deployer",
    })).resolves.toEqual(["0x00000000000000000000000000000000000000A1"]);
  });

  it("rejects listing an encrypted signer without unlock permission", async () => {
    await writeKeystore("deployer", { crypto: {} });

    await expect(listFoundrySignerAddresses({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      accountName: "deployer",
    })).rejects.toThrow(
      "Foundry keystore account 'deployer' needs to be unlocked to verify its public address.",
    );
  });

  it("resolves a selected Compose account without inspecting passthrough flags", async () => {
    await expect(resolveFoundryDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: {
        alias: "deployer",
        address: "0x00000000000000000000000000000000000000a1",
        foundryAccount: "production-deployer",
      },
      passthrough: ["--sender", "0x00000000000000000000000000000000000000a2"],
    })).resolves.toBe("0x00000000000000000000000000000000000000A1");
  });

  it("resolves an explicit Foundry sender from passthrough", async () => {
    await expect(resolveFoundryDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: null,
      passthrough: ["--sender=0x00000000000000000000000000000000000000a1"],
    })).resolves.toBe("0x00000000000000000000000000000000000000A1");
  });

  it("resolves a named Foundry keystore account from passthrough", async () => {
    await writeKeystore("deployer", { address: "00000000000000000000000000000000000000a1" });

    await expect(resolveFoundryDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: null,
      passthrough: ["--account", "deployer"],
    })).resolves.toBe("0x00000000000000000000000000000000000000A1");
  });

  it("leaves an opaque Foundry signing method unresolved", async () => {
    await expect(resolveFoundryDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: null,
      passthrough: ["--private-key", "0xsecret"],
    })).resolves.toBeNull();
  });

  it("skips prediction when a comma list rotates multiple signers", async () => {
    await expect(resolveFoundryDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: null,
      passthrough: ["--accounts", "deployer,other"],
    })).resolves.toBeNull();
    expect(mocks.runCommandCaptureStdout).not.toHaveBeenCalled();
  });

  it("skips prediction when passthrough combines signing sources", async () => {
    await expect(resolveFoundryDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: null,
      passthrough: ["--account", "deployer", "--private-key", "0xsecret"],
    })).resolves.toBeNull();
  });

  it("skips prediction for repeated positional account values", async () => {
    await expect(resolveFoundryDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: null,
      passthrough: ["--accounts", "deployer", "other"],
    })).resolves.toBeNull();
  });

  it("still predicts a single account alongside a keystore password", async () => {
    await writeKeystore("deployer", { address: "00000000000000000000000000000000000000a1" });

    await expect(resolveFoundryDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: null,
      passthrough: ["--account", "deployer", "--password", "pw.txt"],
    })).resolves.toBe("0x00000000000000000000000000000000000000A1");
  });

  it("predicts an explicit sender over a single hardware signer", async () => {
    await expect(resolveFoundryDeploySigner({
      projectRoot,
      chainKey: "local",
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      account: null,
      passthrough: ["--sender", "0x00000000000000000000000000000000000000a1", "--ledger"],
    })).resolves.toBe("0x00000000000000000000000000000000000000A1");
  });

  it("imports a key and parses the reported address", async () => {
    mocks.runCommandCaptureStdout.mockResolvedValue(
      "\nDeployer keystore was saved successfully. Address: 0x00000000000000000000000000000000000000a1\n",
    );

    await expect(importFoundryAccount(projectRoot, "deployer")).resolves.toBe(
      "0x00000000000000000000000000000000000000a1",
    );
    expect(mocks.runCommandCaptureStdout).toHaveBeenCalledWith(
      "cast",
      ["wallet", "import", "deployer", "--interactive"],
      { cwd: projectRoot },
    );
  });
});
