import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { runCommand, runCommandCapture, runCommandCaptureStdout } from "../../src/utils/exec";

let projectRoot: string;

beforeEach(async () => {
  projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-run-command-"));
});

afterEach(async () => {
  await fs.rm(projectRoot, { recursive: true, force: true });
});

const privateKey = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
const mnemonic = "test test test test test test test test test test test junk";
const password = "compose-test-password";
const rpcUrl = "https://user:password@rpc.example.test/v1/api-key?token=query-secret";
const sensitiveArgs = [
  "--private-key",
  privateKey,
  `--mnemonic=${mnemonic}`,
  "--password",
  password,
  "--rpc-url",
  rpcUrl,
];

function expectRedactedCommandError(error: unknown): void {
  expect(error).toBeInstanceOf(Error);
  const message = (error as Error).message;
  for (const secret of [privateKey, mnemonic, password, rpcUrl]) {
    expect(message).not.toContain(secret);
  }
  expect(message).toContain("--private-key [REDACTED]");
  expect(message).toContain("--mnemonic=[REDACTED]");
  expect(message).toContain("--password [REDACTED]");
  expect(message).toContain("--rpc-url [REDACTED]");
}

async function writeFailingScript(): Promise<string> {
  const scriptPath = path.join(projectRoot, "fail.mjs");
  await fs.writeFile(scriptPath, "process.exit(9);\n", "utf8");
  return scriptPath;
}

describe("runCommand environment overrides", () => {
  it("merges command-specific environment values with the parent environment", async () => {
    const resultPath = path.join(projectRoot, "environment.json");
    const rpcUrl = "https://rpc.example.test/v1/private-token";
    const script = [
      'const fs = require("node:fs");',
      `fs.writeFileSync(${JSON.stringify(resultPath)}, JSON.stringify({`,
      "  rpcUrl: process.env.COMPOSE_DEPLOY_RPC_URL,",
      "  path: process.env.PATH,",
      "}));",
    ].join("\n");

    await runCommand(process.execPath, ["-e", script], {
      cwd: projectRoot,
      env: { COMPOSE_DEPLOY_RPC_URL: rpcUrl },
    });

    const result = JSON.parse(await fs.readFile(resultPath, "utf8")) as {
      rpcUrl: string;
      path: string;
    };
    expect(result.rpcUrl).toBe(rpcUrl);
    expect(result.path).toBe(process.env.PATH);
  });

  it("captures stdout without forwarding it when requested", async () => {
    const childOutput = "Foundry public address output";
    const stdoutWrite = vi.spyOn(process.stdout, "write");

    try {
      const output = await runCommandCaptureStdout(
        process.execPath,
        ["-e", `process.stdout.write(${JSON.stringify(childOutput)});`],
        { cwd: projectRoot, forwardStdout: false },
      );

      expect(output).toBe(childOutput);
      expect(stdoutWrite.mock.calls.some(([chunk]) => String(chunk).includes(childOutput))).toBe(false);
    } finally {
      stdoutWrite.mockRestore();
    }
  });
});

describe("command failure errors", () => {
  it("redacts sensitive argv in runCommand errors", async () => {
    const scriptPath = await writeFailingScript();
    const error = await runCommand(
      process.execPath,
      [scriptPath, ...sensitiveArgs],
      { cwd: projectRoot },
    ).catch((caught: unknown) => caught);

    expectRedactedCommandError(error);
  });

  it("redacts sensitive argv in runCommandCaptureStdout errors", async () => {
    const scriptPath = await writeFailingScript();
    const error = await runCommandCaptureStdout(
      process.execPath,
      [scriptPath, ...sensitiveArgs],
      { cwd: projectRoot, forwardStdout: false },
    ).catch((caught: unknown) => caught);

    expectRedactedCommandError(error);
  });

  it("redacts sensitive argv in runCommandCapture errors", async () => {
    const scriptPath = await writeFailingScript();
    const error = await runCommandCapture(
      process.execPath,
      [scriptPath, ...sensitiveArgs],
      { cwd: projectRoot },
    ).catch((caught: unknown) => caught);

    expectRedactedCommandError(error);
  });

  it("does not expose sensitive argv in spawn errors", async () => {
    const error = await runCommand(
      "compose-command-that-does-not-exist",
      ["--private-key", privateKey, "--mnemonic", mnemonic],
      { cwd: projectRoot },
    ).catch((caught: unknown) => caught);

    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).not.toContain(privateKey);
    expect((error as Error).message).not.toContain(mnemonic);
    expect(JSON.stringify(error)).not.toContain(privateKey);
    expect(JSON.stringify(error)).not.toContain(mnemonic);
  });
});
