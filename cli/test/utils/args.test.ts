import { describe, expect, it } from "vitest";
import { assertNoDeploymentNetworkOverrides, toPassthroughArgs } from "../../src/utils/args";

describe("toPassthroughArgs", () => {
  it("keeps only string arguments in order", () => {
    expect(toPassthroughArgs(["--match-test", "test_Increment", 7, null])).toEqual([
      "--match-test",
      "test_Increment",
    ]);
  });

  it("returns an empty list for missing or non-array values", () => {
    expect(toPassthroughArgs(undefined)).toEqual([]);
    expect(toPassthroughArgs("--match-test")).toEqual([]);
  });
});

describe("assertNoDeploymentNetworkOverrides", () => {
  it.each([
    ["foundry", ["--rpc-url", "https://other.example"]],
    ["foundry", ["--rpc-url=https://other.example"]],
    ["foundry", ["--fork-url", "https://other.example"]],
    ["foundry", ["--chain-id", "1"]],
    ["hardhat", ["--network", "other"]],
    ["hardhat", ["--network=other"]],
    ["hardhat", ["--rpc-url", "https://other.example"]],
  ] as const)("rejects conflicting %s passthrough flags", (framework, args) => {
    expect(() => assertNoDeploymentNetworkOverrides(args, framework)).toThrow(
      "cannot change the planned deployment target",
    );
  });

  it("allows signing and other non-network passthrough options", () => {
    expect(() => assertNoDeploymentNetworkOverrides(
      ["--private-key", "0xabc", "--non-interactive"],
      "foundry",
    )).not.toThrow();
    expect(() => assertNoDeploymentNetworkOverrides(["--account", "deployer"], "hardhat")).not.toThrow();
  });

  it("prevents passthrough from replacing a selected Compose signer", () => {
    expect(() => assertNoDeploymentNetworkOverrides(
      ["--account", "another-deployer"],
      "foundry",
      true,
    )).toThrow("conflicts with the selected Compose account");
    expect(() => assertNoDeploymentNetworkOverrides(
      ["--private-key", "0xsecret"],
      "foundry",
      true,
    )).toThrow("conflicts with the selected Compose account");
  });

  it("redacts inline secret values in passthrough errors", () => {
    const expectRedacted = (run: () => void, expected: string): void => {
      let message = "";
      try {
        run();
      } catch (error) {
        message = (error as Error).message;
      }
      expect(message).toContain(expected);
      expect(message).not.toContain("0xsecret");
      expect(message).not.toContain("rpc.example.test/v1/secret");
    };

    expectRedacted(
      () => assertNoDeploymentNetworkOverrides(
        ["--private-key=0xsecret"],
        "foundry",
        false,
        "simulate",
      ),
      "--private-key=[REDACTED]",
    );
    expectRedacted(
      () => assertNoDeploymentNetworkOverrides(
        ["--private-key=0xsecret"],
        "foundry",
        true,
      ),
      "--private-key=[REDACTED]",
    );
    expectRedacted(
      () => assertNoDeploymentNetworkOverrides(
        ["--rpc-url=https://rpc.example.test/v1/secret"],
        "foundry",
      ),
      "--rpc-url=[REDACTED]",
    );
  });

  it("keeps a framework passthrough from changing simulation into a broadcast", () => {
    expect(() => assertNoDeploymentNetworkOverrides(
      ["--broadcast"],
      "foundry",
      false,
      "simulate",
    )).toThrow("cannot change Compose deploy mode");
    expect(() => assertNoDeploymentNetworkOverrides(
      ["--skip-simulation"],
      "foundry",
      false,
      "simulate",
    )).toThrow("disables the requested dry-run");
    expect(() => assertNoDeploymentNetworkOverrides(
      ["--private-key", "0xsecret"],
      "foundry",
      false,
      "simulate",
    )).toThrow("not used for a dry-run");
    expect(() => assertNoDeploymentNetworkOverrides(
      ["--sender", "0x00000000000000000000000000000000000000a1"],
      "foundry",
      false,
      "simulate",
    )).not.toThrow();
  });
});
