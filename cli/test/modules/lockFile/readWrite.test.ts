import { describe, expect, it, beforeEach, afterEach } from "vitest";
import fs from "node:fs/promises";
import path from "node:path";
import { LockFileModule } from "../../../src/modules/lockFile/module";
import { createLockFileHarness, LockFileHarness } from "./harness";

describe("LockFileModule.readLockFile / writeLockFile", () => {
  let harness: LockFileHarness;

  beforeEach(async () => {
    harness = await createLockFileHarness();
  });

  afterEach(async () => {
    await harness.cleanup();
  });

  it("returns null result when lock file doesn't exist", async () => {
    const ctx = await LockFileModule.readLockFile(harness.ctx);
    expect(ctx.state.lockFile?.success).toBe(true);
    expect(ctx.state.lockFile?.result).toBeNull();
  });

  it("writes and reads back lock file atomically", async () => {
    const lock = LockFileModule.createEmptyLock("0.0.3");

    const writeCtx = await LockFileModule.writeLockFile(harness.ctx, lock);
    expect(writeCtx.state.lockFileWrite?.success).toBe(true);

    const readCtx = await LockFileModule.readLockFile(harness.ctx);
    expect(readCtx.state.lockFile?.result?.lock).toEqual(lock);
  });

  it("rejects invalid JSON in lock file", async () => {
    const lockPath = path.join(harness.projectRoot, "compose.lock");
    await fs.writeFile(lockPath, "not valid json {{{", "utf8");

    const ctx = await LockFileModule.readLockFile(harness.ctx);
    expect(ctx.state.lockFile?.success).toBe(false);
    expect(ctx.state.lockFile?.error?.code).toBe("LOCK_FILE_INVALID");
  });

  it("rejects structurally invalid lock file", async () => {
    const lockPath = path.join(harness.projectRoot, "compose.lock");
    await fs.writeFile(lockPath, JSON.stringify({ compose: "0.0.3" }), "utf8");

    const ctx = await LockFileModule.readLockFile(harness.ctx);
    expect(ctx.state.lockFile?.success).toBe(false);
    expect(ctx.state.lockFile?.error?.message).toContain("missing 'deployments'");
  });

  it("handles missing directories", async () => {
    const deepPath = path.join(harness.projectRoot, "a", "b", "c");
    await fs.mkdir(deepPath, { recursive: true });

    const ctx = { ...harness.ctx, param: { projectRoot: deepPath } };
    const lock = LockFileModule.createEmptyLock("0.0.3");

    const writeCtx = await LockFileModule.writeLockFile(ctx, lock);
    expect(writeCtx.state.lockFileWrite?.success).toBe(true);

    const readCtx = await LockFileModule.readLockFile(ctx);
    expect(readCtx.state.lockFile?.result?.lock).toEqual(lock);
  });

  it("overwrites existing lock file", async () => {
    const lock1 = LockFileModule.createEmptyLock("0.0.1");
    const lock2 = LockFileModule.createEmptyLock("0.0.2");

    await LockFileModule.writeLockFile(harness.ctx, lock1);
    await LockFileModule.writeLockFile(harness.ctx, lock2);

    const readCtx = await LockFileModule.readLockFile(harness.ctx);
    expect(readCtx.state.lockFile?.result?.lock).toEqual(lock2);
  });
});
