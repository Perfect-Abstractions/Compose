import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import fs from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";

export const ANVIL_PRIVATE_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const CHAIN_ID = 31337;
const COMPOSE_ROOT = path.resolve(__dirname, "../../../..");
const DIAMOND_FIXTURE = path.join(
  __dirname,
  "..",
  "validatePipeline",
  "fixtures",
  "bytecode",
  "Diamond.sol",
);
const CLI_ENTRY = process.env.COMPOSE_E2E_CLI_ENTRY
  ?? path.join(COMPOSE_ROOT, "cli", "dist", "index.js");

/** Passthrough arguments handing signing to Foundry with the first Anvil key. */
export const SIGNER_ARGS = ["--", "--private-key", ANVIL_PRIVATE_KEY, "--non-interactive"];

type ProcessResult = {
  code: number;
  stdout: string;
  stderr: string;
};

type LockDeployment = {
  diamond: string;
  facets: Record<string, string>;
  facetHash: string;
  lastSync: string;
  txHash: string;
};

export type DeployE2EHarness = {
  projectRoot: string;
  rpcUrl: string;
  runDeploy(args: string[]): Promise<ProcessResult>;
  runValidate(): Promise<ProcessResult>;
  readDeployment(): Promise<LockDeployment>;
  writeComposeJson(facets: Record<string, unknown>): Promise<void>;
  cleanup(): Promise<void>;
};

function runProcess(
  command: string,
  args: string[],
  options: { cwd: string },
): Promise<ProcessResult> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      windowsHide: true,
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk: Buffer) => { stdout += chunk.toString(); });
    child.stderr.on("data", (chunk: Buffer) => { stderr += chunk.toString(); });
    child.once("error", reject);
    child.once("close", (code) => resolve({ code: code ?? 1, stdout, stderr }));
  });
}

async function availablePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      const port = typeof address === "object" && address ? address.port : 0;
      server.close((error) => error ? reject(error) : resolve(port));
    });
  });
}

async function waitForRPC(rpcUrl: string, process: ChildProcessWithoutNullStreams): Promise<void> {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (process.exitCode !== null) throw new Error("Anvil exited before its RPC endpoint was ready.");
    try {
      const response = await fetch(rpcUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] }),
      });
      if (response.ok) return;
    } catch {
      // The endpoint is not listening yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Timed out waiting for Anvil RPC.");
}

const BASE_FACETS = {
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

const EXTRA_FACET = {
  source: "local",
  contract: "src/ExtraFacet.sol:ExtraFacet",
};

const COUNTER_FACET_SOURCE = `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract CounterFacet {
    uint256 private counterValue;

    function increment() external {
        counterValue += 1;
    }

    function counter() external view returns (uint256) {
        return counterValue;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.increment.selector, this.counter.selector);
    }
}
`;

const EXTRA_FACET_SOURCE = `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract ExtraFacet {
    uint256 private doubledValue;

    function double(uint256 value) external {
        doubledValue = value * 2;
    }

    function doubled() external view returns (uint256) {
        return doubledValue;
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.double.selector, this.doubled.selector);
    }
}
`;

async function linkFoundryLibraries(projectRoot: string): Promise<void> {
  const libraryRoot = path.join(projectRoot, "lib");
  await fs.mkdir(libraryRoot, { recursive: true });
  const directoryType = process.platform === "win32" ? "junction" : "dir";
  await Promise.all([
    fs.symlink(COMPOSE_ROOT, path.join(libraryRoot, "Compose"), directoryType),
    fs.symlink(
      path.join(COMPOSE_ROOT, "lib", "forge-std"),
      path.join(libraryRoot, "forge-std"),
      directoryType,
    ),
  ]);
}

async function writeComposeJson(
  projectRoot: string,
  rpcUrl: string,
  facets: Record<string, unknown>,
): Promise<void> {
  await fs.writeFile(
    path.join(projectRoot, "compose.json"),
    JSON.stringify(
      {
        project: "deploy-e2e",
        compose: "0.3.0",
        framework: "foundry",
        diamonds: {
          CounterDiamond: {
            contract: "src/Diamond.sol:Diamond",
            facets,
          },
        },
        chains: {
          local: { rpc: rpcUrl, chainId: CHAIN_ID },
        },
      },
      null,
      2,
    ),
    "utf8",
  );
}

async function createProject(root: string, rpcUrl: string): Promise<string> {
  const projectRoot = path.join(root, "project");
  await Promise.all([
    fs.mkdir(path.join(projectRoot, "src"), { recursive: true }),
    fs.mkdir(path.join(projectRoot, "script"), { recursive: true }),
  ]);
  await linkFoundryLibraries(projectRoot);
  await Promise.all([
    fs.writeFile(
      path.join(projectRoot, "foundry.toml"),
      [
        "[profile.default]",
        'src = "src"',
        'script = "script"',
        'out = "out"',
        'libs = ["lib"]',
        'solc = "0.8.30"',
        "optimizer = true",
        "",
      ].join("\n"),
      "utf8",
    ),
    fs.writeFile(
      path.join(projectRoot, "remappings.txt"),
      "@perfect-abstractions/compose/=lib/Compose/src/\nforge-std/=lib/forge-std/src/\n",
      "utf8",
    ),
    fs.copyFile(DIAMOND_FIXTURE, path.join(projectRoot, "src", "Diamond.sol")),
    fs.writeFile(path.join(projectRoot, "src", "CounterFacet.sol"), COUNTER_FACET_SOURCE, "utf8"),
    fs.writeFile(path.join(projectRoot, "src", "ExtraFacet.sol"), EXTRA_FACET_SOURCE, "utf8"),
  ]);
  await writeComposeJson(projectRoot, rpcUrl, BASE_FACETS);
  return projectRoot;
}

/** Starts Anvil and prepares a Foundry project for `compose deploy` E2E tests. */
export async function createDeployE2EHarness(): Promise<DeployE2EHarness> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-deploy-e2e-"));
  const port = await availablePort();
  const rpcUrl = `http://127.0.0.1:${port}`;
  const anvil = spawn("anvil", ["--silent", "--port", String(port), "--chain-id", String(CHAIN_ID)], {
    cwd: root,
    windowsHide: true,
  });

  try {
    await waitForRPC(rpcUrl, anvil);
    const projectRoot = await createProject(root, rpcUrl);

    return {
      projectRoot,
      rpcUrl,
      runDeploy: (args) =>
        runProcess(process.execPath, [CLI_ENTRY, "deploy", "--project-root", projectRoot, ...args], {
          cwd: projectRoot,
        }),
      runValidate: () =>
        runProcess(process.execPath, [CLI_ENTRY, "validate", "--project-root", projectRoot], {
          cwd: projectRoot,
        }),
      async readDeployment() {
        const lock = JSON.parse(
          await fs.readFile(path.join(projectRoot, "compose.lock"), "utf8"),
        ) as {
          deployments: Record<string, Record<string, Record<string, LockDeployment>>>;
        };
        return lock.deployments.CounterDiamond.local.default;
      },
      async writeComposeJson(facets) {
        await writeComposeJson(projectRoot, rpcUrl, facets);
      },
      async cleanup() {
        anvil.kill("SIGTERM");
        await fs.rm(root, { recursive: true, force: true });
      },
    };
  } catch (error) {
    anvil.kill("SIGTERM");
    await fs.rm(root, { recursive: true, force: true });
    throw error;
  }
}

export { BASE_FACETS, EXTRA_FACET };
