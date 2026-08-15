import { describe, expect, it, afterEach } from "vitest";
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { loadProjectSignatures } from "../../../src/modules/inspect/abiLoader";

let tmpDir: string;

async function setup(projectStructure: Record<string, unknown>): Promise<string> {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "abiLoader-test-"));
  await writeStructure(tmpDir, projectStructure);
  return tmpDir;
}

async function writeStructure(dir: string, structure: Record<string, unknown>): Promise<void> {
  for (const [name, value] of Object.entries(structure)) {
    const fullPath = path.join(dir, name);
    if (typeof value === "string") {
      await fs.mkdir(path.dirname(fullPath), { recursive: true });
      await fs.writeFile(fullPath, value, "utf8");
    } else if (typeof value === "object" && value !== null) {
      await fs.mkdir(fullPath, { recursive: true });
      await writeStructure(fullPath, value as Record<string, unknown>);
    }
  }
}

afterEach(async () => {
  if (tmpDir) {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

describe("loadProjectSignatures", () => {
  it("extracts function signatures from Foundry artifacts", async () => {
    await setup({
      out: {
        "CounterFacet.sol": {
          "CounterFacet.json": JSON.stringify({
            abi: [
              { type: "function", name: "getNumber", inputs: [], outputs: [{ type: "uint256" }] },
              { type: "function", name: "setNumber", inputs: [{ name: "num", type: "uint256" }], outputs: [] },
            ],
          }),
        },
      },
    });

    const map = await loadProjectSignatures(tmpDir, "foundry");

    expect(map.get("0xf2c9ecd8")).toBe("getNumber()");
    expect(map.get("0x3fb5c1cb")).toBe("setNumber(uint256)");
  });

  it("extracts function signatures from Hardhat artifacts", async () => {
    await setup({
      artifacts: {
        contracts: {
          "CounterFacet.sol": {
            "CounterFacet.json": JSON.stringify({
              abi: [
                { type: "function", name: "increment", inputs: [], outputs: [] },
              ],
            }),
          },
        },
      },
    });

    const map = await loadProjectSignatures(tmpDir, "hardhat");

    expect(map.get("0xd09de08a")).toBe("increment()");
  });

  it("handles multiple ABI files", async () => {
    await setup({
      out: {
        "FacetA.sol": {
          "FacetA.json": JSON.stringify({
            abi: [{ type: "function", name: "foo", inputs: [], outputs: [] }],
          }),
        },
        "FacetB.sol": {
          "FacetB.json": JSON.stringify({
            abi: [{ type: "function", name: "bar", inputs: [{ type: "uint256" }], outputs: [] }],
          }),
        },
      },
    });

    const map = await loadProjectSignatures(tmpDir, "foundry");

    expect(map.size).toBeGreaterThanOrEqual(2);
    expect(map.has("0xc2985578")).toBe(true);
    expect(map.has("0x0423a132")).toBe(true);
  });

  it("skips non-function ABI entries", async () => {
    await setup({
      out: {
        "Facet.sol": {
          "Facet.json": JSON.stringify({
            abi: [
              { type: "function", name: "foo", inputs: [], outputs: [] },
              { type: "event", name: "Transfer" },
              { type: "constructor", inputs: [] },
              { type: "error", name: "InsufficientBalance" },
            ],
          }),
        },
      },
    });

    const map = await loadProjectSignatures(tmpDir, "foundry");

    expect(map.size).toBe(1);
  });

  it("returns empty map when artifact directory doesn't exist", async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "abiLoader-empty-"));

    const map = await loadProjectSignatures(tmpDir, "foundry");

    expect(map.size).toBe(0);
  });

  it("skips unparseable JSON files", async () => {
    await setup({
      out: {
        "Bad.sol": {
          "Bad.json": "not valid json {{{",
        },
        "Good.sol": {
          "Good.json": JSON.stringify({
            abi: [{ type: "function", name: "ok", inputs: [], outputs: [] }],
          }),
        },
      },
    });

    const map = await loadProjectSignatures(tmpDir, "foundry");

    expect(map.size).toBe(1);
  });

  it("skips JSON files without abi field", async () => {
    await setup({
      out: {
        "NoAbi.sol": {
          "NoAbi.json": JSON.stringify({ bytecode: "0x6000" }),
        },
      },
    });

    const map = await loadProjectSignatures(tmpDir, "foundry");

    expect(map.size).toBe(0);
  });
});
