import { describe, expect, it, vi } from "vitest";
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

  it("parses upgradeability flags", () => {
    expect(
      parseArgs(["node", "compose", "init", "--base", "none", "--yes", "--immutable"]),
    ).toEqual({
      command: "init",
      flags: {
        framework: "foundry",
        toolbox: "ethers",
        base: "none",
        yes: true,
        immutable: true,
      },
    });

    expect(
      parseArgs(["node", "compose", "init", "--base", "none", "--yes", "--upgradeable"]),
    ).toEqual({
      command: "init",
      flags: {
        framework: "foundry",
        toolbox: "ethers",
        base: "none",
        yes: true,
        upgradeable: true,
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

describe("account command arguments", () => {
  it("parses account setup options", () => {
    expect(parseArgs([
      "node",
      "compose",
      "account",
      "setup",
      "deployer",
      "--address",
      "0x00000000000000000000000000000000000000a1",
      "--foundry-account",
      "prod-key",
      "--chain",
      "sepolia",
    ])).toEqual({
      command: "account",
      flags: {
        action: "setup",
        accountName: "deployer",
        address: "0x00000000000000000000000000000000000000a1",
        foundryAccount: "prod-key",
        chain: "sepolia",
      },
    });
  });

  it("parses account list", () => {
    expect(parseArgs(["node", "compose", "account", "list"])).toEqual({
      command: "account",
      flags: { action: "list" },
    });
  });

  it("parses account check options", () => {
    expect(parseArgs([
      "node",
      "compose",
      "account",
      "check",
      "deployer",
      "--chain",
      "sepolia",
      "--rpc-url",
      "https://rpc.example.test",
    ])).toEqual({
      command: "account",
      flags: {
        action: "check",
        accountName: "deployer",
        chain: "sepolia",
        rpcUrl: "https://rpc.example.test",
      },
    });
  });
});

describe("test command arguments", () => {
  it("accepts a project root and framework passthrough arguments", () => {
    expect(
      parseArgs([
        "node",
        "compose",
        "test",
        "--project-root",
        "./project",
        "--",
        "--match-test",
        "test_Increment",
        "-vvv",
      ]),
    ).toEqual({
      command: "test",
      flags: {
        projectRoot: "./project",
        passthrough: ["--match-test", "test_Increment", "-vvv"],
      },
    });
  });

  it("accepts test without options", () => {
    expect(parseArgs(["node", "compose", "test"])).toEqual({
      command: "test",
      flags: {},
    });
  });
});

describe("deploy command arguments", () => {
  it("defaults chain, instance, and deployment flags", () => {
    expect(parseArgs(["node", "compose", "deploy"])).toEqual({
      command: "deploy",
      flags: { chain: "local", instance: "default" },
    });
  });

  it("parses deploy options", () => {
    expect(
      parseArgs([
        "node",
        "compose",
        "deploy",
        "--diamond",
        "Token",
        "--chain",
        "sepolia",
        "--account",
        "deployer",
        "--instance",
        "staging",
        "--project-root",
        "./project",
        "--broadcast",
        "--redeploy",
      ]),
    ).toEqual({
      command: "deploy",
      flags: {
        diamond: "Token",
        chain: "sepolia",
        account: "deployer",
        instance: "staging",
        projectRoot: "./project",
        broadcast: true,
        redeploy: true,
      },
    });
  });

  it("forwards arguments after -- as passthrough", () => {
    expect(
      parseArgs([
        "node",
        "compose",
        "deploy",
        "--broadcast",
        "--",
        "--private-key",
        "0xabc",
        "--non-interactive",
      ]),
    ).toEqual({
      command: "deploy",
      flags: {
        broadcast: true,
        chain: "local",
        instance: "default",
        passthrough: ["--private-key", "0xabc", "--non-interactive"],
      },
    });
  });

  it("keeps commander strict about unknown options before --", () => {
    const exitSpy = vi
      .spyOn(process, "exit")
      .mockImplementation(((code?: number) => {
        throw new Error(`exit:${code}`);
      }) as never);
    const stderrSpy = vi.spyOn(process.stderr, "write").mockImplementation(() => true);

    try {
      expect(() => parseArgs(["node", "compose", "deploy", "--nope"])).toThrow("exit:1");
    } finally {
      exitSpy.mockRestore();
      stderrSpy.mockRestore();
    }
  });

  it("rejects passthrough arguments for commands that do not accept them", () => {
    expect(() => parseArgs(["node", "compose", "validate", "--", "--ast"])).toThrow(
      "Only 'compose deploy' and 'compose test' accept passthrough arguments.",
    );
    expect(() => parseArgs(["node", "compose", "init", "example", "--", "--foo"])).toThrow(
      "Only 'compose deploy' and 'compose test' accept passthrough arguments.",
    );
  });

  it("redacts sensitive passthrough values in rejection errors", () => {
    let message = "";
    try {
      parseArgs([
        "node",
        "compose",
        "validate",
        "--",
        "--private-key",
        "0xsecret",
        "--mnemonic=test test test",
      ]);
    } catch (error) {
      message = (error as Error).message;
    }

    expect(message).toContain("--private-key [REDACTED]");
    expect(message).toContain("--mnemonic=[REDACTED]");
    expect(message).not.toContain("0xsecret");
    expect(message).not.toContain("test test test");
  });
});
