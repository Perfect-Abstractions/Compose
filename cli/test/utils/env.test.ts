import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { loadProjectEnv } from "../../src/utils/env";

const ENV_KEYS = [
  "COMPOSE_ENV_TEST_PARENT_ONLY",
  "COMPOSE_ENV_TEST_PROJECT_ONLY",
  "COMPOSE_ENV_TEST_NESTED_ONLY",
  "COMPOSE_ENV_TEST_PRECEDENCE",
  "COMPOSE_ENV_TEST_SHELL_VALUE",
];
const originalEnv = new Map(ENV_KEYS.map((key) => [key, process.env[key]]));

beforeEach(() => {
  for (const key of ENV_KEYS) delete process.env[key];
});

afterEach(() => {
  for (const key of ENV_KEYS) {
    const value = originalEnv.get(key);
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
});

describe("loadProjectEnv", () => {
  it("loads only the nearest Compose project's .env and preserves shell values", async () => {
    const outerRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-env-"));
    const projectRoot = path.join(outerRoot, "project");
    const nestedDirectory = path.join(projectRoot, "src", "contracts");

    try {
      await fs.mkdir(nestedDirectory, { recursive: true });
      await fs.writeFile(path.join(projectRoot, "compose.json"), "{}", "utf8");
      await fs.writeFile(
        path.join(outerRoot, ".env"),
        "COMPOSE_ENV_TEST_PARENT_ONLY=parent\nCOMPOSE_ENV_TEST_PRECEDENCE=parent\n",
        "utf8",
      );
      await fs.writeFile(
        path.join(projectRoot, ".env"),
        "COMPOSE_ENV_TEST_PROJECT_ONLY=project\nCOMPOSE_ENV_TEST_PRECEDENCE=project\nCOMPOSE_ENV_TEST_SHELL_VALUE=from-file\n",
        "utf8",
      );
      await fs.writeFile(
        path.join(nestedDirectory, ".env"),
        "COMPOSE_ENV_TEST_NESTED_ONLY=nested\nCOMPOSE_ENV_TEST_PRECEDENCE=nested\n",
        "utf8",
      );
      process.env.COMPOSE_ENV_TEST_SHELL_VALUE = "from-shell";

      await loadProjectEnv(nestedDirectory);

      expect(process.env.COMPOSE_ENV_TEST_PARENT_ONLY).toBeUndefined();
      expect(process.env.COMPOSE_ENV_TEST_PROJECT_ONLY).toBe("project");
      expect(process.env.COMPOSE_ENV_TEST_NESTED_ONLY).toBeUndefined();
      expect(process.env.COMPOSE_ENV_TEST_PRECEDENCE).toBe("project");
      expect(process.env.COMPOSE_ENV_TEST_SHELL_VALUE).toBe("from-shell");
    } finally {
      await fs.rm(outerRoot, { recursive: true, force: true });
    }
  });

  it("uses only the starting directory when no Compose project exists", async () => {
    const outerRoot = await fs.mkdtemp(path.join(os.tmpdir(), "compose-env-no-project-"));
    const startDirectory = path.join(outerRoot, "working");

    try {
      await fs.mkdir(startDirectory, { recursive: true });
      await fs.writeFile(
        path.join(outerRoot, ".env"),
        "COMPOSE_ENV_TEST_PARENT_ONLY=parent\n",
        "utf8",
      );

      await loadProjectEnv(startDirectory);

      expect(process.env.COMPOSE_ENV_TEST_PARENT_ONLY).toBeUndefined();
    } finally {
      await fs.rm(outerRoot, { recursive: true, force: true });
    }
  });
});
