import { describe, expect, it } from "vitest";
import { parseArgs } from "../src/comander";

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
