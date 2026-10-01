import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import fs from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";

const ANVIL_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const CHAIN_ID = 31337;
const COMPOSE_ROOT = path.resolve(__dirname, "../../../..");
const FIXTURE_ROOT = path.join(__dirname, "fixtures", "bytecode");
const CLI_ENTRY = process.env.COMPOSE_E2E_CLI_ENTRY
  ?? path.join(COMPOSE_ROOT, "cli", "dist", "index.js");

type ProcessResult = {
  code: number;
  stdout: string;
  stderr: string;
};

type BroadcastTransaction = {
  contractName?: string;
  contractAddress?: string;
  hash?: string;
};

export type BytecodeE2EHarness = {
  canonicalFacetAddress: string;
  diamondAddress: string;
  rpcUrl: string;
  createValidationProject(variant: "compatible" | "incompatible"): Promise<string>;
  runValidate(projectRoot: string): Promise<ProcessResult>;
  cleanup(): Promise<void>;
};

function runProcess(
  command: string,
  args: string[],
  options: { cwd: string; env?: NodeJS.ProcessEnv },
): Promise<ProcessResult> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env ?? process.env,
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

async function writeFoundryConfig(projectRoot: string): Promise<void> {
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
  ]);
}

async function createDeploymentProject(root: string): Promise<string> {
  const projectRoot = path.join(root, "deployment");
  await Promise.all([
    fs.mkdir(path.join(projectRoot, "src"), { recursive: true }),
    fs.mkdir(path.join(projectRoot, "script"), { recursive: true }),
  ]);
  await linkFoundryLibraries(projectRoot);
  await writeFoundryConfig(projectRoot);
  await Promise.all([
    fs.copyFile(path.join(FIXTURE_ROOT, "Diamond.sol"), path.join(projectRoot, "src", "Diamond.sol")),
    fs.copyFile(
      path.join(FIXTURE_ROOT, "canonical", "CanonicalStorageFacet.sol"),
      path.join(projectRoot, "src", "CanonicalStorageFacet.sol"),
    ),
    fs.copyFile(
      path.join(FIXTURE_ROOT, "script", "Deploy.s.sol"),
      path.join(projectRoot, "script", "Deploy.s.sol"),
    ),
  ]);
  return projectRoot;
}

function packageFacet(contractName: string) {
  return {
    source: "package",
    contract: contractName,
    package: "@perfect-abstractions/compose",
  };
}

/** Starts Anvil and deploys the canonical ERC-20 diamond used by bytecode E2E tests. */
export async function createBytecodeE2EHarness(): Promise<BytecodeE2EHarness> {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "compose-bytecode-e2e-"));
  const port = await availablePort();
  const rpcUrl = `http://127.0.0.1:${port}`;
  const anvil = spawn("anvil", ["--silent", "--port", String(port), "--chain-id", String(CHAIN_ID)], {
    cwd: root,
    windowsHide: true,
  });

  try {
    await waitForRPC(rpcUrl, anvil);
    const deploymentRoot = await createDeploymentProject(root);
    const deployment = await runProcess("forge", [
      "script",
      "script/Deploy.s.sol:DeployScript",
      "--rpc-url",
      rpcUrl,
      "--private-key",
      ANVIL_PRIVATE_KEY,
      "--broadcast",
      "--non-interactive",
    ], { cwd: deploymentRoot });
    if (deployment.code !== 0) {
      throw new Error(`Diamond deployment failed.\n${deployment.stdout}\n${deployment.stderr}`);
    }

    const broadcastPath = path.join(
      deploymentRoot,
      "broadcast",
      "Deploy.s.sol",
      String(CHAIN_ID),
      "run-latest.json",
    );
    const broadcast = JSON.parse(await fs.readFile(broadcastPath, "utf8")) as {
      transactions: BroadcastTransaction[];
    };
    const deployments = new Map(
      broadcast.transactions
        .filter((transaction) => transaction.contractName && transaction.contractAddress)
        .map((transaction) => [transaction.contractName!, transaction]),
    );
    const diamondTransaction = deployments.get("Diamond");
    if (!diamondTransaction?.contractAddress) throw new Error("Diamond address missing from Foundry broadcast.");
    const diamondAddress = diamondTransaction.contractAddress;
    const canonicalFacetAddress = deployments.get("CanonicalStorageFacet")?.contractAddress;
    if (!canonicalFacetAddress) {
      throw new Error("Canonical storage facet address missing from Foundry broadcast.");
    }

    return {
      canonicalFacetAddress,
      diamondAddress,
      rpcUrl,
      async createValidationProject(variant) {
        const contractName = variant === "compatible"
          ? "CompatibleStorageFacet"
          : "IncompatibleStorageFacet";
        const projectRoot = path.join(root, variant);
        await fs.mkdir(path.join(projectRoot, "src"), { recursive: true });
        await linkFoundryLibraries(projectRoot);
        await writeFoundryConfig(projectRoot);
        await Promise.all([
          fs.copyFile(path.join(FIXTURE_ROOT, "Diamond.sol"), path.join(projectRoot, "src", "Diamond.sol")),
          fs.copyFile(
            path.join(FIXTURE_ROOT, variant, `${contractName}.sol`),
            path.join(projectRoot, "src", `${contractName}.sol`),
          ),
        ]);

        const facets = {
          DiamondInspectFacet: packageFacet("DiamondInspectFacet"),
          ERC20DataFacet: packageFacet("ERC20DataFacet"),
          ERC20ApproveFacet: packageFacet("ERC20ApproveFacet"),
          ERC20TransferFacet: packageFacet("ERC20TransferFacet"),
          [contractName]: {
            source: "local",
            contract: `src/${contractName}.sol:${contractName}`,
          },
        };
        await fs.writeFile(path.join(projectRoot, "compose.json"), JSON.stringify({
          project: `bytecode-${variant}`,
          compose: "0.0.6",
          framework: "foundry",
          diamonds: {
            ERC20Diamond: {
              contract: "src/Diamond.sol:Diamond",
              facets,
            },
          },
          chains: {
            local: { rpc: rpcUrl, chainId: CHAIN_ID },
          },
        }, null, 2), "utf8");

        const deployedFacets = Object.fromEntries(
          [...deployments.entries()]
            .filter(([name]) => name !== "Diamond")
            .map(([name, transaction]) => [name, transaction.contractAddress]),
        );
        await fs.writeFile(path.join(projectRoot, "compose.lock"), JSON.stringify({
          compose: "0.0.6",
          deployments: {
            ERC20Diamond: {
              local: {
                diamond: diamondAddress,
                facets: deployedFacets,
                facetHash: "0x00",
                lastSync: new Date().toISOString(),
                txHash: diamondTransaction.hash ?? "0x00",
              },
            },
          },
        }, null, 2), "utf8");
        return projectRoot;
      },
      runValidate: (projectRoot) => runProcess(process.execPath, [
        CLI_ENTRY,
        "validate",
        "--project-root",
        projectRoot,
      ], { cwd: projectRoot }),
      async cleanup() {
        anvil.kill();
        await new Promise<void>((resolve) => {
          if (anvil.exitCode !== null) return resolve();
          anvil.once("close", () => resolve());
          setTimeout(resolve, 2_000);
        });
        await fs.rm(root, { recursive: true, force: true });
      },
    };
  } catch (error) {
    anvil.kill();
    await fs.rm(root, { recursive: true, force: true });
    throw error;
  }
}
