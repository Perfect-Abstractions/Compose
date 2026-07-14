import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";

/**
 * Resolves a command string to its executable path.
 * Currently a passthrough; can be extended to handle
 * PATH lookups, nvm version resolution, or other logic.
 *
 * @param command - The command to resolve.
 * @returns The resolved command string.
 */
function resolveCommand(command: string): string {
  return command;
}

/**
 * Spawns a child process with the given command and arguments.
 * Returns a Promise that resolves when the process exits with code 0,
 * or rejects on non-zero exit or spawn errors.
 * On Windows, uses shell mode for npm/npx to avoid .cmd extension issues.
 *
 * @param command - The command to execute.
 * @param args - Arguments to pass to the command.
 * @param options - Optional spawn options (e.g., working directory).
 * @returns A Promise that resolves on success or rejects on failure.
 */
export function runCommand(command: string, args: string[], options?: { cwd?: string }): Promise<void> {
  return new Promise((resolve, reject) => {
    const resolvedCommand = resolveCommand(command);
    const useShell = process.platform === "win32" && (command === "npm" || command === "npx");
    const child = spawn(resolvedCommand, args, {
      stdio: "inherit",
      shell: useShell,
      ...options,
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`Command failed: ${command} ${args.join(" ")} (exit ${code})`));
    });
  });
}

/**
 * Checks whether a binary exists in the system PATH.
 *
 * @param binaryName - Name of the binary to find (e.g., "node", "forge").
 * @throws {Error} If the binary is not found in PATH.
 */
export async function isBinaryInPath(binaryName: string): Promise<void> {
  const pathEnv = process.env.PATH || "";
  const separator = process.platform === "win32" ? ";" : ":";
  const paths = pathEnv.split(separator);
  const extensions = process.platform === "win32" ? [".exe", ".cmd", ".bat", ""] : [""];

  for (const currentPath of paths) {
    for (const extension of extensions) {
      const candidate = path.join(currentPath, `${binaryName}${extension}`);
      try {
        await fs.access(candidate);
        return;
      } catch {
        continue;
      }
    }
  }

  throw new Error(`${binaryName} not found in PATH. Please install ${binaryName} and try again.`);
}
