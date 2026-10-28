import { describe, expect, it } from "vitest";
import {
  formatCommandArgs,
  redactCommandArgs,
  redactSensitiveArgument,
} from "../../src/utils/redaction";

describe("redactCommandArgs", () => {
  it("redacts separate values for sensitive flags", () => {
    expect(redactCommandArgs([
      "--private-key",
      "0xprivate",
      "--mnemonic",
      "test test test test test test test test test test test junk",
      "--password",
      "hunter2",
      "--non-interactive",
    ])).toEqual([
      "--private-key",
      "[REDACTED]",
      "--mnemonic",
      "[REDACTED]",
      "--password",
      "[REDACTED]",
      "--non-interactive",
    ]);
  });

  it("redacts inline values for sensitive flags", () => {
    expect(redactCommandArgs([
      "--private-key=0xprivate",
      "--mnemonic=test test",
      "--password=hunter2",
      "--unsafe-password=hunter2",
    ])).toEqual([
      "--private-key=[REDACTED]",
      "--mnemonic=[REDACTED]",
      "--password=[REDACTED]",
      "--unsafe-password=[REDACTED]",
    ]);
  });

  it("redacts every value for multi-value sensitive flags", () => {
    expect(redactCommandArgs([
      "--private-keys",
      "0xprivate1",
      "0xprivate2",
      "--mnemonics",
      "phrase one",
      "phrase two",
      "--non-interactive",
    ])).toEqual([
      "--private-keys",
      "[REDACTED]",
      "[REDACTED]",
      "--mnemonics",
      "[REDACTED]",
      "[REDACTED]",
      "--non-interactive",
    ]);
  });

  it("redacts RPC endpoints and camelCase secret flags", () => {
    expect(redactCommandArgs([
      "--rpc-url",
      "https://user:password@rpc.example/v1/api-key",
      "--fork-url=https://rpc.example/v1/api-key",
      "--privateKey=0xprivate",
      "--apikey=api-secret",
      "--secret-key=0xsecret",
      "--keystore=/home/user/.foundry/keystores/deployer",
    ])).toEqual([
      "--rpc-url",
      "[REDACTED]",
      "--fork-url=[REDACTED]",
      "--privateKey=[REDACTED]",
      "--apikey=[REDACTED]",
      "--secret-key=[REDACTED]",
      "--keystore=[REDACTED]",
    ]);
  });

  it("keeps non-sensitive public arguments intact", () => {
    const args = [
      "script/ComposeDeploy.s.sol:ComposeDeploy",
      "--account",
      "deployer",
      "--sender",
      "0x00000000000000000000000000000000000000a1",
      "--match-test",
      "test_Increment",
    ];
    expect(redactCommandArgs(args)).toEqual(args);
  });

  it("does not treat the next flag as a sensitive value", () => {
    expect(redactCommandArgs(["--private-key", "--non-interactive"])).toEqual([
      "--private-key",
      "--non-interactive",
    ]);
  });
});

describe("formatCommandArgs", () => {
  it("formats a redacted command line", () => {
    expect(formatCommandArgs(["--private-key", "0xprivate", "--broadcast"])).toBe(
      "--private-key [REDACTED] --broadcast",
    );
  });
});

describe("redactSensitiveArgument", () => {
  it("redacts inline secret values", () => {
    expect(redactSensitiveArgument("--private-key=0xprivate")).toBe(
      "--private-key=[REDACTED]",
    );
  });

  it("preserves flags without an attached value", () => {
    expect(redactSensitiveArgument("--private-key")).toBe("--private-key");
  });
});
