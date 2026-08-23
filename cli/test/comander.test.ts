import { describe, expect, it } from "vitest";
import { parseArgs } from "../src/comander";

describe("validate command arguments", () => {
  it("accepts a Compose project root", () => {
    expect(parseArgs(["node", "compose", "validate", "--project-root", "./example"])).toEqual({
      command: "validate",
      flags: { projectRoot: "./example" },
    });
  });
});

describe("init command arguments", () => {
  it("normalizes --out to the project output directory parameter", () => {
    expect(
      parseArgs([
        "node",
        "compose",
        "init",
        "example",
        "--base",
        "counter",
        "--out",
        "./projects",
        "--yes",
      ]),
    ).toEqual({
      command: "init",
      flags: {
        framework: "foundry",
        toolbox: "ethers",
        projectName: "example",
        base: "counter",
        outDir: "./projects",
        yes: true,
      },
    });
  });
});

describe("rpc command", () => {
  it("parses chain and optional address flags", () => {
    const result = parseArgs([
      "node",
      "compose",
      "rpc",
      "--chain",
      "sepolia",
      "--address",
      "0x0000000000000000000000000000000000000001",
    ]);

    expect(result).toEqual({
      command: "rpc",
      flags: {
        chain: "sepolia",
        address: "0x0000000000000000000000000000000000000001",
      },
    });
  });

  it("defaults rpc checks to local", () => {
    expect(parseArgs(["node", "compose", "rpc"])).toEqual({
      command: "rpc",
      flags: { chain: "local" },
    });
  });
});

describe("inspect command", () => {
  it("parses address positional and chain flag", () => {
    const result = parseArgs([
      "node",
      "compose",
      "inspect",
      "0x0000000000000000000000000000000000000001",
      "--chain",
      "sepolia",
    ]);

    expect(result).toEqual({
      command: "inspect",
      flags: {
        address: "0x0000000000000000000000000000000000000001",
        chain: "sepolia",
      },
    });
  });

  it("defaults chain to local", () => {
    const result = parseArgs([
      "node",
      "compose",
      "inspect",
      "0x0000000000000000000000000000000000000001",
    ]);

    expect(result).toEqual({
      command: "inspect",
      flags: {
        address: "0x0000000000000000000000000000000000000001",
        chain: "local",
      },
    });
  });

});
