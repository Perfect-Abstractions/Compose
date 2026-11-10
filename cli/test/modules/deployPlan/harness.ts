import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { Context } from "../../../src/context/context";
import type { ComposeContext } from "../../../src/context/types";

export type DeployProjectHarness = {
  ctx: ComposeContext;
  projectRoot: string;
  scriptRoot: string;
  writeComposeJson(
    diamondFacets?: Record<string, unknown>,
    options?: { framework?: "foundry" | "hardhat" },
  ): Promise<void>;
  writeLock(deployments: Record<string, unknown>): Promise<void>;
  cleanup(): Promise<void>;
};

export const RPC_URL = "http://127.0.0.1:8545";
export const CHAIN_ID = 31337;

export const DEFAULT_FACETS = {
  DiamondInspectFacet: {
    source: "package",
    contract: "DiamondInspectFacet",
    package: "@perfect-abstractions/compose",
  },
  CounterFacet: {
    source: "local",
    contract: "src/CounterFacet.sol:CounterFacet",
  },
};

const DIAMOND_ADDRESS = "0x00000000000000000000000000000000000000aa";
const FACET_ADDRESS_A = "0x00000000000000000000000000000000000000b1";
const FACET_ADDRESS_B = "0x00000000000000000000000000000000000000b2";

const FIXTURE_FILES: Array<[string, string]> = [
  ["src/Diamond.sol", "// fixture\ncontract Diamond {}\n"],
  ["src/CounterFacet.sol", "// fixture\ncontract CounterFacet {}\n"],
  ["src/DiamondUpgradeFacet.sol", "// fixture\ncontract DiamondUpgradeFacet {}\n"],
  [
    "lib/Compose/src/diamond/DiamondInspectFacet.sol",
    "// fixture\ncontract DiamondInspectFacet {}\n",
  ],
];

/** Builds a deployment record with valid addresses for lock fixtures. */
export function deploymentRecord(facets: Record<string, string>): Record<string, unknown> {
  return {
    diamond: DIAMOND_ADDRESS,
    facets,
    facetHash: `0x${"11".repeat(32)}`,
    lastSync: "2026-01-01T00:00:00.000Z",
    txHash: `0x${"22".repeat(32)}`,
  };
}

/** Facet addresses matching {@link DEFAULT_FACETS}, for matching lock records. */
export const DEFAULT_FACET_ADDRESSES = {
  DiamondInspectFacet: FACET_ADDRESS_A,
  CounterFacet: FACET_ADDRESS_B,
};

/**
 * Creates a temp Compose project fixture for deploy plan and pipeline tests.
 *
 * The fixture mirrors the layout the CLI resolves against: a local facet, a
 * Compose package facet under `lib/Compose/src`, and compose.json with a
 * single diamond and the `local` chain pointing at {@link RPC_URL}.
 */
export async function createDeployProjectHarness(): Promise<DeployProjectHarness> {
  const projectRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-deploy-"));
  const scriptRoot = path.join(projectRoot, "script");
  await fs.mkdir(scriptRoot, { recursive: true });

  await Promise.all(
    FIXTURE_FILES.map(async ([relativePath, content]) => {
      const filePath = path.join(projectRoot, relativePath);
      await fs.mkdir(path.dirname(filePath), { recursive: true });
      await fs.writeFile(filePath, content, "utf8");
    }),
  );

  const ctx = Context.create();
  ctx.param.command = "deploy";
  ctx.param.projectRoot = projectRoot;

  const harness: DeployProjectHarness = {
    ctx,
    projectRoot,
    scriptRoot,
    async writeComposeJson(diamondFacets = DEFAULT_FACETS, options = {}) {
      const framework = options.framework ?? "foundry";
      await fs.writeFile(
        path.join(projectRoot, "compose.json"),
        JSON.stringify(
          {
            project: "fixture",
            compose: "0.3.0",
            framework,
            diamonds: {
              CounterDiamond: {
                contract: "src/Diamond.sol:Diamond",
                facets: diamondFacets,
              },
            },
            chains: {
              local: { rpc: RPC_URL, chainId: CHAIN_ID },
            },
          },
          null,
          2,
        ),
        "utf8",
      );
      if (framework === "hardhat") {
        await fs.writeFile(
          path.join(projectRoot, "package.json"),
          JSON.stringify({
            type: "module",
            devDependencies: {
              hardhat: "^3.8.0",
              "@nomicfoundation/hardhat-toolbox-mocha-ethers": "^3.0.0",
            },
          }, null, 2),
          "utf8",
        );
      }
    },
    async writeLock(deployments) {
      await fs.writeFile(
        path.join(projectRoot, "compose.lock"),
        JSON.stringify({ compose: "0.3.0", deployments }, null, 2),
        "utf8",
      );
    },
    cleanup: () => fs.rm(projectRoot, { recursive: true, force: true }),
  };

  await harness.writeComposeJson();
  return harness;
}
