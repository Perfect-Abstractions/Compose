import { describe, expect, it } from "vitest";
import { foundryAdapter } from "../../../src/adapters/IFrameworkAdapter/foundryAdapter/adapter";
import { hardhatAdapter } from "../../../src/adapters/IFrameworkAdapter/hardhatAdapter/adapter";

describe("Foundry adapter test command", () => {
  it("builds forge test and forwards passthrough arguments", () => {
    expect(
      foundryAdapter.createTestCommand({
        projectRoot: "/project",
        passthrough: ["--match-test", "test_Increment", "-vvv"],
      }),
    ).toEqual({
      command: "forge",
      args: ["test", "--match-test", "test_Increment", "-vvv"],
    });
  });

  it("builds a bare forge test command", () => {
    expect(
      foundryAdapter.createTestCommand({ projectRoot: "/project", passthrough: [] }),
    ).toEqual({
      command: "forge",
      args: ["test"],
    });
  });
});

describe("Hardhat adapter test command", () => {
  it("builds hardhat test and forwards passthrough arguments", () => {
    expect(
      hardhatAdapter.createTestCommand({
        projectRoot: "/project",
        passthrough: ["--grep", "increment"],
      }),
    ).toEqual({
      command: "npx",
      args: ["hardhat", "test", "--grep", "increment"],
    });
  });

  it("builds a bare hardhat test command", () => {
    expect(
      hardhatAdapter.createTestCommand({ projectRoot: "/project", passthrough: [] }),
    ).toEqual({
      command: "npx",
      args: ["hardhat", "test"],
    });
  });
});
