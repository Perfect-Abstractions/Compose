import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { formatCommandArgs } from "./redaction";

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
 * Replaces a raw spawn error, which may retain the full argv in `spawnargs`,
 * with an error that only exposes the executable and error code.
 *
 * @param command - The command that failed to start.
 * @param error - The original spawn error.
 * @returns A sanitized error preserving the original error code.
 */
function commandStartError(command: string, error: unknown): Error {
  const code = typeof error === "object" && error && "code" in error
    ? String((error as { code?: unknown }).code)
    : undefined;
  const failure = new Error(
    `Command failed to start: ${command}${code ? ` (${code})` : ""}`,
  ) as NodeJS.ErrnoException;
  if (code) failure.code = code;
  return failure;
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
export function runCommand(
  command: string,
  args: string[],
  options?: { cwd?: string; env?: NodeJS.ProcessEnv },
): Promise<void> {
  return new Promise((resolve, reject) => {
    const resolvedCommand = resolveCommand(command);
    const useShell = process.platform === "win32" && (command === "npm" || command === "npx");
    const spawnOptions = { ...options };
    if (options?.env) {
      spawnOptions.env = { ...process.env, ...options.env };
    }
    const child = spawn(resolvedCommand, args, {
      stdio: "inherit",
      shell: useShell,
      ...spawnOptions,
    });
    child.on("error", (error) => reject(commandStartError(command, error)));
    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`Command failed: ${command} ${formatCommandArgs(args)} (exit ${code})`));
    });
  });
}

/** Runs a command while optionally forwarding and also returning its stdout. */
export function runCommandCaptureStdout(
  command: string,
  args: string[],
  options?: { cwd?: string; env?: NodeJS.ProcessEnv; forwardStdout?: boolean },
): Promise<string> {
  return new Promise((resolve, reject) => {
    const resolvedCommand = resolveCommand(command);
    const useShell = process.platform === "win32" && (command === "npm" || command === "npx");
    const { forwardStdout = true, ...spawnOptions } = options ?? {};
    if (spawnOptions.env) spawnOptions.env = { ...process.env, ...spawnOptions.env };
    const child = spawn(resolvedCommand, args, {
      stdio: ["inherit", "pipe", "inherit"],
      shell: useShell,
      ...spawnOptions,
    });

    let stdout = "";
    child.stdout?.on("data", (chunk: Buffer) => {
      const text = chunk.toString();
      stdout += text;
      if (forwardStdout) process.stdout.write(text);
    });
    child.on("error", (error) => reject(commandStartError(command, error)));
    child.on("exit", (code) => {
      if (code === 0) {
        resolve(stdout);
        return;
      }
      reject(new Error(`Command failed: ${command} ${formatCommandArgs(args)} (exit ${code})`));
    });
  });
}

/**
 * Checks whether a binary exists in the system PATH.
 *
 * @param binaryName - Name of the binary to find (e.g., "node", "forge").
 * @throws {Error} If the binary is not found in PATH.
 */
export function runCommandCapture(
  command: string,
  args: string[],
  options?: { cwd?: string },
): Promise<void> {
  return new Promise((resolve, reject) => {
    const resolvedCommand = resolveCommand(command);
    const useShell = process.platform === "win32" && (command === "npm" || command === "npx");
    const child = spawn(resolvedCommand, args, {
      stdio: ["inherit", "pipe", "pipe"],
      shell: useShell,
      ...options,
    });

    let stderr = "";
    child.stderr?.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => reject(commandStartError(command, error)));
    child.on("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      if (stderr) {
        process.stderr.write(stderr);
      }
      reject(new Error(`Compilation failed: ${command} ${formatCommandArgs(args)} (exit ${code})`));
    });
  });
}

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
