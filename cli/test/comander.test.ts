import { describe, expect, it } from "vitest";
import { buildProgram, parseArgs } from "../src/comander";

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
  it("is the only facet and selector listing command", () => {
    const commands = buildProgram().commands.map((command) => command.name());
    expect(commands).toContain("inspect");
    expect(commands).not.toContain("selectors");
  });

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

describe("facet configuration commands", () => {
  it("parses direct install arguments and batch manifest options", () => {
    expect(parseArgs([
      "node",
      "compose",
      "install",
      "ERC20BurnFacet",
      "src/facets/FeeFacet.sol:FeeFacet",
      "--diamond",
      "Token",
      "--project-root",
      "./project",
    ])).toEqual({
      command: "install",
      flags: {
        facets: ["ERC20BurnFacet", "src/facets/FeeFacet.sol:FeeFacet"],
        diamond: "Token",
        projectRoot: "./project",
      },
    });

    expect(parseArgs(["node", "compose", "install", "--manifest", "add-fees"])).toEqual({
      command: "install",
      flags: { manifest: "add-fees" },
    });
  });

  it("normalizes the i and rm aliases to canonical command names", () => {
    expect(parseArgs(["node", "compose", "i", "FacetA", "--diamond", "Token"])).toEqual({
      command: "install",
      flags: { facets: ["FacetA"], diamond: "Token" },
    });
    expect(parseArgs(["node", "compose", "rm", "FacetA", "--diamond", "Token"])).toEqual({
      command: "remove",
      flags: { facets: ["FacetA"], diamond: "Token" },
    });
  });
});
